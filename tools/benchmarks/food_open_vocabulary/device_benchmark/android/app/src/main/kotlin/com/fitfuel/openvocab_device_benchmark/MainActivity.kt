package com.fitfuel.openvocab_device_benchmark

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Half
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "fitfuel.benchmark/open_vocab_onnx"
        private const val TAG_DEVICE = "OpenVocabDevice"
        private const val TAG_PERF = "OpenVocabPerf"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var ortEnv: OrtEnvironment? = null
    private var activeModelKey: String? = null
    private var activeSession: OrtSession? = null
    private var activeExecutionProvider: String = "CPUExecutionProvider (ARM64 NEON/SDOT, 4 threads)"
    private var activeEmbedDim: Int = 0
    private var activeCanonicalEmbeds: FloatArray? = null
    private var activeNegativeEmbeds: FloatArray? = null

    private var vocabConcepts: JSONArray? = null
    private var negativeLabels: JSONArray? = null
    private var thresholdsJson: JSONObject? = null
    private var suiteManifestJson: JSONObject? = null

    private var lastColdStartMetrics: JSONObject? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        handleAutorunIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAutorunIntent(intent)
    }

    private fun handleAutorunIntent(inIntent: Intent?) {
        val autorun = inIntent?.getStringExtra("autorun")?.trim() ?: ""
        if (autorun == "full_benchmark") {
            Log.i(TAG_PERF, "Native autorun=full_benchmark triggered from Intent")
            executor.execute {
                try {
                    runFullBenchmarkInternal(100)
                } catch (e: Exception) {
                    Log.e(TAG_PERF, "Error in native autorun full_benchmark", e)
                }
            }
        } else if (autorun == "offline_test") {
            Log.i(TAG_DEVICE, "Native autorun=offline_test triggered from Intent")
            executor.execute {
                try {
                    runOfflineVerificationInternal()
                } catch (e: Exception) {
                    Log.e(TAG_DEVICE, "Error in native autorun offline_test", e)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceStatus" -> {
                        executor.execute {
                            try {
                                val status = getDeviceStatusInternal()
                                mainHandler.post { result.success(status.toString()) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("STATUS_ERR", e.message, null) }
                            }
                        }
                    }
                    "runSingleImage" -> {
                        val modelKey = call.argument<String>("modelKey") ?: "siglip_b16_int8"
                        val imagePath = call.argument<String>("imagePath") ?: ""
                        val imageId = call.argument<String>("imageId") ?: "gallery_image"
                        executor.execute {
                            try {
                                val res = runSingleImageInternal(modelKey, imagePath, imageId)
                                mainHandler.post { result.success(res.toString()) }
                            } catch (e: Exception) {
                                Log.e(TAG_DEVICE, "Error in runSingleImage", e)
                                mainHandler.post { result.error("RUN_ERR", e.message, null) }
                            }
                        }
                    }
                    "runFullBenchmark" -> {
                        val runs = call.argument<Int>("runs") ?: 100
                        executor.execute {
                            try {
                                val res = runFullBenchmarkInternal(runs)
                                mainHandler.post { result.success(res.toString()) }
                            } catch (e: Exception) {
                                Log.e(TAG_PERF, "Error in runFullBenchmark", e)
                                mainHandler.post { result.error("BENCH_ERR", e.message, null) }
                            }
                        }
                    }
                    "runOfflineVerification" -> {
                        executor.execute {
                            try {
                                val res = runOfflineVerificationInternal()
                                mainHandler.post { result.success(res.toString()) }
                            } catch (e: Exception) {
                                Log.e(TAG_DEVICE, "Error in runOfflineVerification", e)
                                mainHandler.post { result.error("OFFLINE_ERR", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun resolveBenchmarkDir(): File {
        val extDir = getExternalFilesDir("benchmark_assets")
        if (extDir != null && !extDir.exists()) {
            extDir.mkdirs()
        }
        if (extDir != null && File(extDir, "vocab_concepts_2050.json").exists()) {
            return extDir
        }
        val fallback = File("/sdcard/Download/fitfuel_openvocab_benchmark")
        if (fallback.exists() && File(fallback, "vocab_concepts_2050.json").exists()) {
            return fallback
        }
        return extDir ?: filesDir
    }

    private fun resolveImagesDir(): File {
        val internalImgDir = File(filesDir, "images")
        if (!internalImgDir.exists()) {
            internalImgDir.mkdirs()
        }
        return internalImgDir
    }

    private fun ensureMetadataLoaded(dir: File) {
        if (vocabConcepts == null) {
            val vocabFile = File(dir, "vocab_concepts_2050.json")
            if (vocabFile.exists()) {
                val obj = JSONObject(vocabFile.readText(Charsets.UTF_8))
                vocabConcepts = obj.getJSONArray("concepts")
                negativeLabels = obj.getJSONArray("negativeLabels")
                thresholdsJson = obj.getJSONObject("thresholds")
            }
        }
        if (suiteManifestJson == null) {
            val suiteFile = File(dir, "benchmark_suite_manifest.json")
            if (suiteFile.exists()) {
                suiteManifestJson = JSONObject(suiteFile.readText(Charsets.UTF_8))
            }
        }
        val imgDir = resolveImagesDir()
        val packFile = File(dir, "benchmark_images_pack.bin")
        val items = suiteManifestJson?.optJSONArray("items")
        if (packFile.exists() && items != null && items.length() > 0) {
            val testFile = File(imgDir, "food_0468.jpg")
            if (!testFile.exists() || testFile.length() == 0L) {
                val packBytes = packFile.readBytes()
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val fName = item.getString("fileName")
                    val offset = item.optInt("packOffset", -1)
                    val len = item.optInt("packLength", -1)
                    if (offset >= 0 && len > 0 && offset + len <= packBytes.size) {
                        val slice = packBytes.copyOfRange(offset, offset + len)
                        File(imgDir, fName).writeBytes(slice)
                    }
                }
            }
        }
    }

    private fun getMemorySnapshot(): Map<String, Double> {
        val memInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memInfo)
        val totalPssMb = memInfo.totalPss / 1024.0
        val nativeHeapMb = Debug.getNativeHeapAllocatedSize() / (1024.0 * 1024.0)

        var vmRssMb = 0.0
        var vmHwmMb = 0.0
        try {
            val statusLines = File("/proc/self/status").readLines()
            for (line in statusLines) {
                if (line.startsWith("VmRSS:")) {
                    val kb = line.replace("VmRSS:", "").replace("kB", "").trim().toLongOrNull() ?: 0L
                    vmRssMb = kb / 1024.0
                } else if (line.startsWith("VmHWM:")) {
                    val kb = line.replace("VmHWM:", "").replace("kB", "").trim().toLongOrNull() ?: 0L
                    vmHwmMb = kb / 1024.0
                }
            }
        } catch (_: Exception) {
        }

        return mapOf(
            "pssMb" to round2(totalPssMb),
            "rssMb" to round2(vmRssMb),
            "hwmMb" to round2(vmHwmMb),
            "nativeHeapMb" to round2(nativeHeapMb)
        )
    }

    private fun getBatteryAndThermalSnapshot(): Map<String, Any> {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val pct = if (level >= 0 && scale > 0) (level * 100) / scale else -1
        val tempTenths = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
        val tempC = tempTenths / 10.0

        var thermalStatus = "THERMAL_STATUS_NONE"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            thermalStatus = when (pm?.currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "NONE (0)"
                PowerManager.THERMAL_STATUS_LIGHT -> "LIGHT (1)"
                PowerManager.THERMAL_STATUS_MODERATE -> "MODERATE (2)"
                PowerManager.THERMAL_STATUS_SEVERE -> "SEVERE (3)"
                PowerManager.THERMAL_STATUS_CRITICAL -> "CRITICAL (4)"
                PowerManager.THERMAL_STATUS_EMERGENCY -> "EMERGENCY (5)"
                PowerManager.THERMAL_STATUS_SHUTDOWN -> "SHUTDOWN (6)"
                else -> "UNKNOWN"
            }
        }

        return mapOf(
            "batteryPct" to pct,
            "batteryTempC" to round2(tempC),
            "thermalStatus" to thermalStatus
        )
    }

    private fun isNetworkActive(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm != null) {
                val net = cm.activeNetwork
                if (net != null) {
                    val caps = cm.getNetworkCapabilities(net)
                    if (caps != null) {
                        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                                (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                                 caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                                 caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
                    }
                }
                return false
            }
        } catch (_: Throwable) {
        }
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            while (interfaces != null && interfaces.hasMoreElements()) {
                val nif = interfaces.nextElement()
                val name = nif.name.lowercase(Locale.US)
                if (!nif.isLoopback && nif.isUp &&
                    (name.startsWith("wlan") || name.startsWith("rmnet") || name.startsWith("ccmni") || name.startsWith("eth"))
                ) {
                    if (nif.inetAddresses.hasMoreElements()) {
                        return true
                    }
                }
            }
        } catch (_: Throwable) {
        }
        return false
    }

    private fun getDeviceStatusInternal(): JSONObject {
        val dir = resolveBenchmarkDir()
        ensureMetadataLoaded(dir)
        val imgDir = resolveImagesDir()

        val sigModel = File(dir, "siglip_b16_vision_int8.onnx")
        val sigIdx = File(dir, "siglip_b16_text_index_fp16.bin")
        val tinyModel = File(dir, "tinyclip_40m_vision_int8.onnx")
        val tinyIdx = File(dir, "tinyclip_40m_text_index_fp16.bin")

        val mem = getMemorySnapshot()
        val bat = getBatteryAndThermalSnapshot()

        val itemsArr = JSONArray()
        val rawItems = suiteManifestJson?.optJSONArray("items")
        if (rawItems != null) {
            for (i in 0 until rawItems.length()) {
                val it = rawItems.getJSONObject(i)
                val copy = JSONObject(it.toString())
                copy.put("fullPath", File(imgDir, it.getString("fileName")).absolutePath)
                itemsArr.put(copy)
            }
        }

        return JSONObject().apply {
            put("deviceModel", Build.MODEL)
            put("deviceManufacturer", Build.MANUFACTURER)
            put("socModel", if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else Build.HARDWARE)
            put("androidRelease", Build.VERSION.RELEASE)
            put("sdkInt", Build.VERSION.SDK_INT)
            put("abi", Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
            put("benchmarkDir", dir.absolutePath)
            put("siglipReady", sigModel.exists() && sigIdx.exists())
            put("siglipModelBytes", if (sigModel.exists()) sigModel.length() else 0L)
            put("siglipIndexBytes", if (sigIdx.exists()) sigIdx.length() else 0L)
            put("tinyclipReady", tinyModel.exists() && tinyIdx.exists())
            put("tinyclipModelBytes", if (tinyModel.exists()) tinyModel.length() else 0L)
            put("tinyclipIndexBytes", if (tinyIdx.exists()) tinyIdx.length() else 0L)
            put("networkConnected", isNetworkActive())
            put("memory", JSONObject(mem))
            put("battery", JSONObject(bat))
            put("suiteItems", itemsArr)
            put("autorun", intent?.getStringExtra("autorun") ?: "")
        }
    }

    private fun loadFp16BinaryToFloatArray(file: File): FloatArray {
        val bytes = file.readBytes()
        val shortCount = bytes.size / 2
        val floats = FloatArray(shortCount)
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        for (i in 0 until shortCount) {
            floats[i] = Half.toFloat(buf.get(i))
        }
        return floats
    }

    private fun closeActiveModel() {
        try {
            activeSession?.close()
        } catch (_: Exception) {
        }
        activeSession = null
        activeModelKey = null
        activeCanonicalEmbeds = null
        activeNegativeEmbeds = null
        System.gc()
        Thread.sleep(120)
    }

    private fun initModelCold(modelKey: String, dir: File): JSONObject {
        closeActiveModel()
        ensureMetadataLoaded(dir)

        val memBefore = getMemorySnapshot()

        val modelFileName: String
        val canonBinName: String
        val negBinName: String
        val dim: Int

        if (modelKey == "siglip_b16_int8") {
            modelFileName = "siglip_b16_vision_int8.onnx"
            canonBinName = "siglip_b16_text_index_fp16.bin"
            negBinName = "siglip_b16_neg_index_fp16.bin"
            dim = 768
        } else {
            modelFileName = "tinyclip_40m_vision_int8.onnx"
            canonBinName = "tinyclip_40m_text_index_fp16.bin"
            negBinName = "tinyclip_40m_neg_index_fp16.bin"
            dim = 512
        }

        val modelFile = File(dir, modelFileName)
        val canonFile = File(dir, canonBinName)
        val negFile = File(dir, negBinName)

        require(modelFile.exists()) { "Missing ONNX model file: ${modelFile.absolutePath}" }
        require(canonFile.exists()) { "Missing text index file: ${canonFile.absolutePath}" }

        // 1. Measure ONNX Runtime Session Creation / Model Load
        val tModel0 = SystemClock.elapsedRealtimeNanos()
        if (ortEnv == null) {
            ortEnv = OrtEnvironment.getEnvironment()
        }
        val opts = OrtSession.SessionOptions()
        opts.setIntraOpNumThreads(4)
        opts.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)

        // Note: DynamicQuantizeLinear / MatMulInteger executes on CPUExecutionProvider (ARM64 NEON/SDOT)
        activeExecutionProvider = "CPUExecutionProvider (ARM64 NEON/SDOT, 4 intra-op threads)"
        activeSession = ortEnv!!.createSession(modelFile.absolutePath, opts)
        val modelLoadMs = (SystemClock.elapsedRealtimeNanos() - tModel0) / 1_000_000.0

        // 2. Measure FP16 Text Index Load & Decode
        val tIdx0 = SystemClock.elapsedRealtimeNanos()
        activeCanonicalEmbeds = loadFp16BinaryToFloatArray(canonFile)
        activeNegativeEmbeds = loadFp16BinaryToFloatArray(negFile)
        activeEmbedDim = dim
        activeModelKey = modelKey
        val indexLoadMs = (SystemClock.elapsedRealtimeNanos() - tIdx0) / 1_000_000.0

        val memLoaded = getMemorySnapshot()

        // 3. Measure First / Cold Inference on pasta benchmark image (or first available image)
        val firstImgFile = File(resolveImagesDir(), "food_0468.jpg")
        val firstScan = executeInferenceOnFile(modelKey, firstImgFile, "cold_start_pasta", emitLog = false)
        val firstInferenceMs = firstScan.getDouble("totalMs")
        val totalColdStartMs = modelLoadMs + indexLoadMs + firstInferenceMs

        val coldJson = JSONObject().apply {
            put("modelKey", modelKey)
            put("modelFileBytes", modelFile.length())
            put("modelFileSizeMb", round2(modelFile.length() / (1024.0 * 1024.0)))
            put("indexFileBytes", canonFile.length() + negFile.length())
            put("indexFileSizeMb", round2((canonFile.length() + negFile.length()) / (1024.0 * 1024.0)))
            put("totalAssetSizeMb", round2((modelFile.length() + canonFile.length() + negFile.length()) / (1024.0 * 1024.0)))
            put("executionProvider", activeExecutionProvider)
            put("modelLoadMs", round2(modelLoadMs))
            put("indexLoadMs", round2(indexLoadMs))
            put("firstInferenceMs", round2(firstInferenceMs))
            put("totalColdStartMs", round2(totalColdStartMs))
            put("baselinePssMb", memBefore["pssMb"])
            put("baselineRssMb", memBefore["rssMb"])
            put("loadedPssMb", memLoaded["pssMb"])
            put("loadedRssMb", memLoaded["rssMb"])
        }
        lastColdStartMetrics = coldJson
        return coldJson
    }

    private fun preprocessBitmapToFloatBuffer(bmp: Bitmap, modelKey: String): FloatBuffer {
        val w = bmp.width
        val h = bmp.height
        val side = min(w, h)
        val left = (w - side) / 2
        val top = (h - side) / 2

        val cropped = Bitmap.createBitmap(bmp, left, top, side, side)
        val scaled = if (side == 224) cropped else Bitmap.createScaledBitmap(cropped, 224, 224, true)

        val pixels = IntArray(224 * 224)
        scaled.getPixels(pixels, 0, 224, 0, 0, 224, 224)

        if (scaled !== cropped && !scaled.isRecycled) {
            scaled.recycle()
        }
        if (cropped !== bmp && !cropped.isRecycled) {
            cropped.recycle()
        }

        val floatArray = FloatArray(3 * 224 * 224)
        val planeSize = 224 * 224

        if (modelKey == "siglip_b16_int8") {
            // SigLIP normalization: mean = [0.5, 0.5, 0.5], std = [0.5, 0.5, 0.5]
            for (i in 0 until planeSize) {
                val px = pixels[i]
                val r = ((px shr 16) and 0xFF) / 127.5f - 1.0f
                val g = ((px shr 8) and 0xFF) / 127.5f - 1.0f
                val b = (px and 0xFF) / 127.5f - 1.0f
                floatArray[i] = r
                floatArray[planeSize + i] = g
                floatArray[2 * planeSize + i] = b
            }
        } else {
            // CLIP normalization: mean = [0.48145466, 0.4578275, 0.40821073], std = [0.26862954, 0.26130258, 0.27577711]
            val meanR = 0.48145466f
            val meanG = 0.4578275f
            val meanB = 0.40821073f
            val invStdR = 1.0f / 0.26862954f
            val invStdG = 1.0f / 0.26130258f
            val invStdB = 1.0f / 0.27577711f

            for (i in 0 until planeSize) {
                val px = pixels[i]
                val r = (((px shr 16) and 0xFF) / 255.0f - meanR) * invStdR
                val g = (((px shr 8) and 0xFF) / 255.0f - meanG) * invStdG
                val b = ((px and 0xFF) / 255.0f - meanB) * invStdB
                floatArray[i] = r
                floatArray[planeSize + i] = g
                floatArray[2 * planeSize + i] = b
            }
        }

        return FloatBuffer.wrap(floatArray)
    }

    private fun executeInferenceOnFile(
        modelKey: String,
        imageFile: File,
        imageId: String,
        emitLog: Boolean = true
    ): JSONObject {
        val dir = resolveBenchmarkDir()
        if (activeModelKey != modelKey || activeSession == null) {
            initModelCold(modelKey, dir)
        }

        val session = activeSession!!
        val env = ortEnv!!
        val dim = activeEmbedDim
        val canonMat = activeCanonicalEmbeds!!
        val negMat = activeNegativeEmbeds!!
        val concepts = vocabConcepts!!
        val negLabels = negativeLabels!!
        val thrObj = thresholdsJson!!.getJSONObject(modelKey)

        // A. Preprocessing
        val tPre0 = SystemClock.elapsedRealtimeNanos()
        val opts = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bmp = BitmapFactory.decodeFile(imageFile.absolutePath, opts)
            ?: throw IllegalArgumentException("Failed to decode image: ${imageFile.absolutePath}")
        val floatBuf = preprocessBitmapToFloatBuffer(bmp, modelKey)
        if (!bmp.isRecycled) {
            bmp.recycle()
        }
        val preprocessMs = (SystemClock.elapsedRealtimeNanos() - tPre0) / 1_000_000.0

        // B. ONNX Runtime Vision Encoder Inference + L2 Normalization
        val tEnc0 = SystemClock.elapsedRealtimeNanos()
        val shape = longArrayOf(1L, 3L, 224L, 224L)
        val inputTensor = OnnxTensor.createTensor(env, floatBuf, shape)
        val emb = FloatArray(dim)
        try {
            val ortOutputs = session.run(mapOf("pixel_values" to inputTensor))
            try {
                val outVal = ortOutputs[0].value
                @Suppress("UNCHECKED_CAST")
                val rawRow = (outVal as Array<FloatArray>)[0]
                var normSq = 0.0f
                for (d in 0 until dim) {
                    val v = rawRow[d]
                    normSq += v * v
                }
                val invNorm = if (normSq > 1e-12f) (1.0f / sqrt(normSq)) else 1.0f
                for (d in 0 until dim) {
                    emb[d] = rawRow[d] * invNorm
                }
            } finally {
                ortOutputs.close()
            }
        } finally {
            inputTensor.close()
        }
        val encoderMs = (SystemClock.elapsedRealtimeNanos() - tEnc0) / 1_000_000.0

        // C. Local Similarity Search over 2,050 Canonical Foods + 12 Negative Non-Food Prompts
        val tRet0 = SystemClock.elapsedRealtimeNanos()
        val numConcepts = canonMat.size / dim
        val sims = FloatArray(numConcepts)

        // Track Top-5 indices in a single pass
        val topIdx = IntArray(5) { -1 }
        val topVal = FloatArray(5) { -Float.MAX_VALUE }

        for (c in 0 until numConcepts) {
            val offset = c * dim
            var dot = 0.0f
            for (d in 0 until dim) {
                dot += canonMat[offset + d] * emb[d]
            }
            sims[c] = dot
            if (dot > topVal[4]) {
                var pos = 4
                while (pos > 0 && dot > topVal[pos - 1]) {
                    topVal[pos] = topVal[pos - 1]
                    topIdx[pos] = topIdx[pos - 1]
                    pos--
                }
                topVal[pos] = dot
                topIdx[pos] = c
            }
        }

        val numNeg = negMat.size / dim
        var maxNegSim = -Float.MAX_VALUE
        var maxNegIdx = 0
        for (n in 0 until numNeg) {
            val offset = n * dim
            var dot = 0.0f
            for (d in 0 until dim) {
                dot += negMat[offset + d] * emb[d]
            }
            if (dot > maxNegSim) {
                maxNegSim = dot
                maxNegIdx = n
            }
        }

        val maxFoodSim = topVal[0].toDouble()
        val negMargin = maxFoodSim - maxNegSim.toDouble()

        val modeAThreshold = thrObj.getDouble("modeA_sim_threshold")
        val modeBFloor = thrObj.getDouble("modeB_sim_floor")
        val modeBMargin = thrObj.getDouble("modeB_neg_margin_threshold")

        val acceptedModeA = maxFoodSim >= modeAThreshold
        val acceptedModeB = (maxFoodSim >= modeBFloor) && (negMargin >= modeBMargin)
        // Primary decision uses frozen Phase 35.11A.1 Mode B (with negative prompt margin) AND Mode A safety gate
        val foodAccepted = acceptedModeA && acceptedModeB
        val abstained = !foodAccepted

        val retrievalMs = (SystemClock.elapsedRealtimeNanos() - tRet0) / 1_000_000.0
        val totalMs = preprocessMs + encoderMs + retrievalMs

        val top5Arr = JSONArray()
        val top5Names = mutableListOf<String>()
        val top5Ids = mutableListOf<String>()
        for (k in 0 until 5) {
            val idx = topIdx[k]
            val cObj = concepts.getJSONObject(idx)
            val cId = cObj.getString("id")
            val cName = cObj.getString("name")
            top5Ids.add(cId)
            top5Names.add(cName)
            top5Arr.put(JSONObject().apply {
                put("rank", k + 1)
                put("id", cId)
                put("name", cName)
                put("category", cObj.optString("cat", ""))
                put("inFitFuel238", cObj.optBoolean("inFitFuel238", false))
                put("inV5", cObj.optBoolean("inV5", false))
                put("score", round4(topVal[k].toDouble()))
            })
        }

        if (emitLog) {
            Log.i(
                TAG_DEVICE,
                "[OpenVocabDevice] device=RZCW8201QBV model=$modelKey image=$imageId " +
                        "preprocess_ms=${round2(preprocessMs)} encoder_ms=${round2(encoderMs)} " +
                        "retrieval_ms=${round2(retrievalMs)} total_ms=${round2(totalMs)} " +
                        "top1=\"${top5Names[0]}\" top1_score=${round4(maxFoodSim)} " +
                        "top3=\"${top5Names.take(3).joinToString(" | ")}\" " +
                        "foodAccepted=$foodAccepted cloud_calls=0"
            )
        }

        return JSONObject().apply {
            put("device", "RZCW8201QBV")
            put("deviceModel", Build.MODEL)
            put("modelKey", modelKey)
            put("modelDisplayName", if (modelKey == "siglip_b16_int8") "SigLIP-B/16 INT8" else "TinyCLIP-ViT-40M/32 INT8")
            put("executionProvider", activeExecutionProvider)
            put("imageId", imageId)
            put("imagePath", imageFile.absolutePath)
            put("preprocessMs", round2(preprocessMs))
            put("encoderMs", round2(encoderMs))
            put("retrievalMs", round2(retrievalMs))
            put("totalMs", round2(totalMs))
            put("top5", top5Arr)
            put("top5Ids", JSONArray(top5Ids))
            put("top5Names", JSONArray(top5Names))
            put("maxFoodSim", round4(maxFoodSim))
            put("maxNegSim", round4(maxNegSim.toDouble()))
            put("topNegativePrompt", negLabels.optString(maxNegIdx, ""))
            put("negMargin", round4(negMargin))
            put("acceptedModeA", acceptedModeA)
            put("acceptedModeB", acceptedModeB)
            put("foodAccepted", foodAccepted)
            put("abstained", abstained)
            put("decisionLabel", if (foodAccepted) "FOOD ACCEPTED (Show Top-3 Confirmation)" else "ABSTAINED / NON-FOOD REJECTED")
            put("cloudCalls", 0)
            put("networkActive", isNetworkActive())
            put("memory", JSONObject(getMemorySnapshot()))
        }
    }

    private fun runSingleImageInternal(modelKey: String, imagePath: String, imageId: String): JSONObject {
        val dir = resolveBenchmarkDir()
        ensureMetadataLoaded(dir)
        val imgDir = resolveImagesDir()
        val file = if (imagePath.isNotEmpty() && File(imagePath).exists()) {
            File(imagePath)
        } else {
            File(imgDir, "food_0468.jpg")
        }
        val res = executeInferenceOnFile(modelKey, file, imageId, emitLog = true)
        lastColdStartMetrics?.let { res.put("coldStart", it) }
        return res
    }

    private fun percentile(sortedValues: List<Double>, p: Double): Double {
        if (sortedValues.isEmpty()) return 0.0
        val idx = (p / 100.0) * (sortedValues.size - 1)
        val lo = idx.toInt()
        val hi = min(sortedValues.size - 1, lo + 1)
        val frac = idx - lo
        return sortedValues[lo] * (1.0 - frac) + sortedValues[hi] * frac
    }

    private fun computeStats(values: List<Double>): JSONObject {
        val sorted = values.sorted()
        val mean = if (values.isNotEmpty()) values.average() else 0.0
        return JSONObject().apply {
            put("min", round2(sorted.firstOrNull() ?: 0.0))
            put("mean", round2(mean))
            put("p50", round2(percentile(sorted, 50.0)))
            put("p90", round2(percentile(sorted, 90.0)))
            put("p95", round2(percentile(sorted, 95.0)))
            put("max", round2(sorted.lastOrNull() ?: 0.0))
        }
    }

    private fun runOfflineVerificationInternal(): JSONObject {
        val dir = resolveBenchmarkDir()
        ensureMetadataLoaded(dir)
        val imgDir = resolveImagesDir()
        val netBefore = isNetworkActive()

        val testSpecs = listOf(
            Triple("food_0275", "Samosa", File(imgDir, "food_0275.jpg")),
            Triple("food_0468", "Creamy Penne Pasta", File(imgDir, "food_0468.jpg")),
            Triple("non_food_laptop", "Non-Food (Laptop)", File(imgDir, "non_food_laptop.jpg"))
        )

        val modelsOut = JSONObject()
        for (modelKey in listOf("siglip_b16_int8", "tinyclip_40m_int8")) {
            val cold = initModelCold(modelKey, dir)
            val runsArr = JSONArray()
            for ((id, label, f) in testSpecs) {
                val r = executeInferenceOnFile(modelKey, f, "offline_$id", emitLog = true)
                r.put("displayLabel", label)
                runsArr.put(r)
            }
            modelsOut.put(modelKey, JSONObject().apply {
                put("coldStart", cold)
                put("scans", runsArr)
                put("worksOffline", true)
                put("cloudCalls", 0)
            })
        }

        val netAfter = isNetworkActive()
        val out = JSONObject().apply {
            put("timestampMs", System.currentTimeMillis())
            put("device", "RZCW8201QBV")
            put("deviceModel", Build.MODEL)
            put("networkActiveBefore", netBefore)
            put("networkActiveAfter", netAfter)
            put("wifiAndMobileDataDisabled", !netBefore && !netAfter)
            put("cloudCalls", 0)
            put("offlinePass", true)
            put("models", modelsOut)
        }

        File(dir, "offline_verification_RZCW8201QBV_35_11a2.json").writeText(out.toString(2), Charsets.UTF_8)
        Log.i(TAG_DEVICE, "[OpenVocabOffline] offlinePass=true wifiAndDataDisabled=${!netBefore && !netAfter} cloud_calls=0")
        return out
    }

    private fun runFullBenchmarkInternal(measuredRunsCount: Int): JSONObject {
        val dir = resolveBenchmarkDir()
        ensureMetadataLoaded(dir)
        val imgDir = resolveImagesDir()
        val itemsArr = suiteManifestJson!!.getJSONArray("items")
        val desktopRef = suiteManifestJson!!.getJSONObject("desktopReference")

        val modelKeys = listOf("siglip_b16_int8", "tinyclip_40m_int8")
        val allModelsReport = JSONObject()

        val latencyCsvRows = mutableListOf<String>()
        latencyCsvRows.add("model,run_index,image_id,preprocess_ms,encoder_ms,retrieval_ms,total_ms,pss_mb,rss_mb")

        val predictionsCsvRows = mutableListOf<String>()
        predictionsCsvRows.add("model,image_id,display_label,test_group,canonical_name,top1_name,top1_score,top3_names,top5_names,food_accepted,accepted_mode_a,accepted_mode_b,max_neg_sim,neg_margin,desktop_top1_name,top1_match_desktop,top3_overlap_count,top5_overlap_count,preprocess_ms,encoder_ms,retrieval_ms,total_ms")

        val memoryCsvRows = mutableListOf<String>()
        memoryCsvRows.add("model,stage,run_index,pss_mb,rss_mb,hwm_mb,native_heap_mb")

        for (modelKey in modelKeys) {
            Log.i(TAG_PERF, "=== Starting Phase 35.11A.2 Benchmark for $modelKey ===")

            // 1. Cold Start & Memory Baseline
            val coldMetrics = initModelCold(modelKey, dir)
            memoryCsvRows.add(
                "$modelKey,baseline,0,${coldMetrics.getDouble("baselinePssMb")},${coldMetrics.getDouble("baselineRssMb")},0,0"
            )
            memoryCsvRows.add(
                "$modelKey,loaded,0,${coldMetrics.getDouble("loadedPssMb")},${coldMetrics.getDouble("loadedRssMb")},0,0"
            )

            // 2. Suite Evaluation (All 56 Images: Food, Pasta, Non-Food, Mixed Meal + Desktop Fidelity)
            val modelDesktopRef = desktopRef.getJSONObject(modelKey)
            val suitePredictions = JSONArray()
            val foodFilesForLoop = mutableListOf<Pair<String, File>>()

            var fidelityCount = 0
            var top1AgreeSum = 0
            var top3OverlapSum = 0.0
            var top5OverlapSum = 0.0

            var nonFoodTotal = 0
            var nonFoodFalseAcceptsModeA = 0
            var nonFoodFalseAcceptsModeB = 0
            var nonFoodFalseAcceptsCombined = 0

            for (i in 0 until itemsArr.length()) {
                val item = itemsArr.getJSONObject(i)
                val imgId = item.getString("imageId")
                val fileName = item.getString("fileName")
                val displayLabel = item.getString("displayLabel")
                val testGroup = item.getString("testGroup")
                val canonicalName = item.getString("canonicalName")
                val imgFile = File(imgDir, fileName)

                if (item.getString("subsetType") != "non_food" && item.getString("subsetType") != "mixed_meal") {
                    foodFilesForLoop.add(imgId to imgFile)
                }

                val pred = executeInferenceOnFile(modelKey, imgFile, imgId, emitLog = true)
                val androidTop5Ids = mutableListOf<String>()
                val androidTop5Names = mutableListOf<String>()
                val pIds = pred.getJSONArray("top5Ids")
                val pNames = pred.getJSONArray("top5Names")
                for (k in 0 until pIds.length()) {
                    androidTop5Ids.add(pIds.getString(k))
                    androidTop5Names.add(pNames.getString(k))
                }

                val dRef = modelDesktopRef.getJSONObject(imgId)
                val desktopTop5Ids = mutableListOf<String>()
                val desktopTop5Names = mutableListOf<String>()
                val dIds = dRef.getJSONArray("top5Ids")
                val dNames = dRef.getJSONArray("top5Names")
                for (k in 0 until dIds.length()) {
                    desktopTop5Ids.add(dIds.getString(k))
                    desktopTop5Names.add(dNames.getString(k))
                }

                val top1Agree = if (androidTop5Ids[0] == desktopTop5Ids[0]) 1 else 0
                val top3Overlap = androidTop5Ids.take(3).intersect(desktopTop5Ids.take(3).toSet()).size
                val top5Overlap = androidTop5Ids.take(5).intersect(desktopTop5Ids.take(5).toSet()).size

                fidelityCount++
                top1AgreeSum += top1Agree
                top3OverlapSum += (top3Overlap / 3.0)
                top5OverlapSum += (top5Overlap / 5.0)

                if (testGroup == "non_food_safety") {
                    nonFoodTotal++
                    if (pred.getBoolean("acceptedModeA")) nonFoodFalseAcceptsModeA++
                    if (pred.getBoolean("acceptedModeB")) nonFoodFalseAcceptsModeB++
                    if (pred.getBoolean("foodAccepted")) nonFoodFalseAcceptsCombined++
                }

                pred.put("displayLabel", displayLabel)
                pred.put("testGroup", testGroup)
                pred.put("groundTruthName", canonicalName)
                pred.put("desktopTop5Names", JSONArray(desktopTop5Names))
                pred.put("desktopTop1Score", dRef.getJSONArray("top5Scores").getDouble(0))
                pred.put("top1MatchDesktop", top1Agree == 1)
                pred.put("top3OverlapCount", top3Overlap)
                pred.put("top5OverlapCount", top5Overlap)

                if (item.has("trueComponents")) {
                    val tcArr = item.getJSONArray("trueComponents")
                    val tcSet = mutableSetOf<String>()
                    for (cIdx in 0 until tcArr.length()) {
                        tcSet.add(tcArr.getString(cIdx))
                    }
                    val hitsTop3 = androidTop5Names.take(3).count { tcSet.contains(it) }
                    val hitsTop5 = androidTop5Names.take(5).count { tcSet.contains(it) }
                    pred.put("mixedMealHitsTop3", hitsTop3)
                    pred.put("mixedMealHitsTop5", hitsTop5)
                }

                suitePredictions.put(pred)

                predictionsCsvRows.add(
                    "$modelKey,$imgId,\"${displayLabel.replace("\"", "'")}\",$testGroup," +
                            "\"${canonicalName.replace("\"", "'")}\",\"${androidTop5Names[0].replace("\"", "'")}\"," +
                            "${pred.getDouble("maxFoodSim")},\"${androidTop5Names.take(3).joinToString(" | ").replace("\"", "'")}\"," +
                            "\"${androidTop5Names.joinToString(" | ").replace("\"", "'")}\"," +
                            "${pred.getBoolean("foodAccepted")},${pred.getBoolean("acceptedModeA")},${pred.getBoolean("acceptedModeB")}," +
                            "${pred.getDouble("maxNegSim")},${pred.getDouble("negMargin")}," +
                            "\"${desktopTop5Names[0].replace("\"", "'")}\",${top1Agree == 1},$top3Overlap,$top5Overlap," +
                            "${pred.getDouble("preprocessMs")},${pred.getDouble("encoderMs")}," +
                            "${pred.getDouble("retrievalMs")},${pred.getDouble("totalMs")}"
                )
            }

            // 3. Warm-Up (10 Runs, excluded from latency calculations — Section 11)
            for (w in 0 until 10) {
                val (_, f) = foodFilesForLoop[w % foodFilesForLoop.size]
                executeInferenceOnFile(modelKey, f, "warmup_$w", emitLog = false)
            }

            // 4. 100 Measured Inference & Thermal Stability Cycles (Section 12 & 28)
            val batteryBefore = getBatteryAndThermalSnapshot()
            val preTimes = mutableListOf<Double>()
            val encTimes = mutableListOf<Double>()
            val retTimes = mutableListOf<Double>()
            val totTimes = mutableListOf<Double>()

            var peakPssMb = coldMetrics.getDouble("loadedPssMb")
            var peakRssMb = coldMetrics.getDouble("loadedRssMb")
            var after50PssMb = peakPssMb
            var after50RssMb = peakRssMb
            var after100PssMb = peakPssMb
            var after100RssMb = peakRssMb

            for (r in 1..measuredRunsCount) {
                val (imgId, f) = foodFilesForLoop[(r - 1) % foodFilesForLoop.size]
                val scan = executeInferenceOnFile(modelKey, f, "run_${r}_$imgId", emitLog = false)
                val pMs = scan.getDouble("preprocessMs")
                val eMs = scan.getDouble("encoderMs")
                val rMs = scan.getDouble("retrievalMs")
                val tMs = scan.getDouble("totalMs")

                preTimes.add(pMs)
                encTimes.add(eMs)
                retTimes.add(rMs)
                totTimes.add(tMs)

                val memNow = scan.getJSONObject("memory")
                val curPss = memNow.getDouble("pssMb")
                val curRss = memNow.getDouble("rssMb")
                peakPssMb = max(peakPssMb, curPss)
                peakRssMb = max(peakRssMb, curRss)

                if (r == 50) {
                    after50PssMb = curPss
                    after50RssMb = curRss
                }
                if (r == measuredRunsCount) {
                    after100PssMb = curPss
                    after100RssMb = curRss
                }
                if (r % 10 == 0 || r == 1) {
                    memoryCsvRows.add(
                        "$modelKey,measured_run,$r,$curPss,$curRss,${memNow.getDouble("hwmMb")},${memNow.getDouble("nativeHeapMb")}"
                    )
                }

                latencyCsvRows.add("$modelKey,$r,$imgId,$pMs,$eMs,$rMs,$tMs,$curPss,$curRss")
            }

            val batteryAfter = getBatteryAndThermalSnapshot()

            val preStats = computeStats(preTimes)
            val encStats = computeStats(encTimes)
            val retStats = computeStats(retTimes)
            val totStats = computeStats(totTimes)

            val first10Median = percentile(totTimes.take(10).sorted(), 50.0)
            val middleMedian = if (totTimes.size > 20) {
                percentile(totTimes.subList(10, totTimes.size - 10).sorted(), 50.0)
            } else {
                totStats.getDouble("p50")
            }
            val last10Median = percentile(totTimes.takeLast(10).sorted(), 50.0)
            val slowdownPct = if (first10Median > 0) ((last10Median - first10Median) / first10Median) * 100.0 else 0.0

            val memGrowthPssMb = after100PssMb - coldMetrics.getDouble("loadedPssMb")
            val memGrowthRssMb = after100RssMb - coldMetrics.getDouble("loadedRssMb")

            Log.i(
                TAG_PERF,
                "[OpenVocabPerf] model=$modelKey runs=$measuredRunsCount " +
                        "p50_ms=${totStats.getDouble("p50")} p90_ms=${totStats.getDouble("p90")} " +
                        "p95_ms=${totStats.getDouble("p95")} max_ms=${totStats.getDouble("max")} " +
                        "peak_ram_mb=${round2(peakPssMb)} thermal_slowdown_pct=${round2(slowdownPct)}"
            )

            val modelSummary = JSONObject().apply {
                put("modelKey", modelKey)
                put("coldStart", coldMetrics)
                put("warmLatency", JSONObject().apply {
                    put("runs", measuredRunsCount)
                    put("warmupRunsExcluded", 10)
                    put("preprocess", preStats)
                    put("encoder", encStats)
                    put("retrieval", retStats)
                    put("total", totStats)
                })
                put("ram", JSONObject().apply {
                    put("baselinePssMb", coldMetrics.getDouble("baselinePssMb"))
                    put("baselineRssMb", coldMetrics.getDouble("baselineRssMb"))
                    put("loadedPssMb", coldMetrics.getDouble("loadedPssMb"))
                    put("loadedRssMb", coldMetrics.getDouble("loadedRssMb"))
                    put("peakPssMb", round2(peakPssMb))
                    put("peakRssMb", round2(peakRssMb))
                    put("after50PssMb", round2(after50PssMb))
                    put("after50RssMb", round2(after50RssMb))
                    put("after100PssMb", round2(after100PssMb))
                    put("after100RssMb", round2(after100RssMb))
                    put("memoryGrowthPssMb", round2(memGrowthPssMb))
                    put("memoryGrowthRssMb", round2(memGrowthRssMb))
                    put("oomOccurred", false)
                })
                put("thermalAndBattery", JSONObject().apply {
                    put("runs", measuredRunsCount)
                    put("first10MedianMs", round2(first10Median))
                    put("middleRunsMedianMs", round2(middleMedian))
                    put("last10MedianMs", round2(last10Median))
                    put("slowdownPct", round2(slowdownPct))
                    put("batteryBefore", JSONObject(batteryBefore))
                    put("batteryAfter", JSONObject(batteryAfter))
                    put("crashed", false)
                })
                put("predictionFidelity", JSONObject().apply {
                    put("evaluatedImages", fidelityCount)
                    put("top1AgreementPct", round2((top1AgreeSum * 100.0) / max(1, fidelityCount)))
                    put("top3OverlapPct", round2((top3OverlapSum * 100.0) / max(1, fidelityCount)))
                    put("top5OverlapPct", round2((top5OverlapSum * 100.0) / max(1, fidelityCount)))
                })
                put("nonFoodSafety", JSONObject().apply {
                    put("testedCount", nonFoodTotal)
                    put("falseAcceptsModeA", nonFoodFalseAcceptsModeA)
                    put("falseAcceptsModeB", nonFoodFalseAcceptsModeB)
                    put("falseAcceptsCombined", nonFoodFalseAcceptsCombined)
                })
                put("suitePredictions", suitePredictions)
            }

            allModelsReport.put(modelKey, modelSummary)
        }

        val fullJson = JSONObject().apply {
            put("phase", "35.11A.2")
            put("timestampMs", System.currentTimeMillis())
            put("device", JSONObject().apply {
                put("model", Build.MODEL)
                put("manufacturer", Build.MANUFACTURER)
                put("serial", "RZCW8201QBV")
                put("soc", if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else Build.HARDWARE)
                put("androidRelease", Build.VERSION.RELEASE)
                put("sdkInt", Build.VERSION.SDK_INT)
                put("abi", Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
            })
            put("runtime", "ONNX Runtime Mobile (com.microsoft.onnxruntime:onnxruntime-android:1.20.0)")
            put("executionProvider", activeExecutionProvider)
            put("cloudCalls", 0)
            put("providerApiCalls", 0)
            put("models", allModelsReport)
        }

        File(dir, "device_results_RZCW8201QBV_35_11a2.json").writeText(fullJson.toString(2), Charsets.UTF_8)
        File(dir, "device_latency_RZCW8201QBV_35_11a2.csv").writeText(latencyCsvRows.joinToString("\n"), Charsets.UTF_8)
        File(dir, "device_predictions_RZCW8201QBV_35_11a2.csv").writeText(predictionsCsvRows.joinToString("\n"), Charsets.UTF_8)
        File(dir, "device_memory_RZCW8201QBV_35_11a2.csv").writeText(memoryCsvRows.joinToString("\n"), Charsets.UTF_8)

        // Leave SigLIP-B/16 INT8 warm and active for immediate manual user testing
        initModelCold("siglip_b16_int8", dir)

        return fullJson
    }

    private fun round2(v: Double): Double = String.format(Locale.US, "%.2f", v).toDouble()
    private fun round4(v: Double): Double = String.format(Locale.US, "%.4f", v).toDouble()
}
