package com.example.fitfuel

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Half
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "fitfuel/open_vocab_food_recognizer"
        private const val TAG_CASCADE = "FoodScanCascade"
        private const val TAG_PERF = "FoodScanLocalPerf"
        private const val MODEL_VERSION = "siglip_b16_int8"
        private const val EMBED_DIM = 768

        private const val VISION_MODEL_FILE = "siglip_b16_vision_int8.onnx"
        private const val TEXT_INDEX_FILE = "siglip_b16_text_index_fp16.bin"
        private const val NEG_INDEX_FILE = "siglip_b16_neg_index_fp16.bin"
        private const val VOCAB_JSON_FILE = "vocab_concepts_2050.json"
        private const val DYNAMIC_VOCAB_FILE = "dynamic_vocab_packs.json"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null

    private var ortEnv: OrtEnvironment? = null
    private var activeSession: OrtSession? = null
    private var activeCanonicalEmbeds: FloatArray? = null
    private var activeNegativeEmbeds: FloatArray? = null
    private var vocabConcepts: JSONArray? = null
    private var negativeLabels: JSONArray? = null
    private var thresholdsJson: JSONObject? = null
    private var activeExecutionProvider: String =
        "CPUExecutionProvider (ARM64 NEON/SDOT, 4 intra-op threads)"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getStringExtra("validate_35_11b") == "true") {
            val mode = intent.getStringExtra("validate_mode") ?: "online"
            val valDir = getExternalFilesDir("validation_images")?.absolutePath ?: ""
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "triggerValidation",
                    mapOf(
                        "shouldRun" to true,
                        "mode" to mode,
                        "validationDir" to valDir
                    )
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    executor.execute {
                        val available = checkAssetsAvailableInternal()
                        mainHandler.post {
                            result.success(mapOf("available" to available))
                        }
                    }
                }
                "resolveAssets" -> {
                    executor.execute {
                        try {
                            val resolved = resolveOrExtractAssetsInternal()
                            mainHandler.post { result.success(resolved) }
                        } catch (e: Exception) {
                            Log.w(TAG_CASCADE, "resolveAssets failed: ${e.message}")
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "available" to false,
                                        "error" to (e.message ?: "Failed to resolve assets")
                                    )
                                )
                            }
                        }
                    }
                }
                "initialize" -> {
                    executor.execute {
                        try {
                            val t0 = SystemClock.elapsedRealtimeNanos()
                            val wasCold = activeSession == null
                            ensureSessionInitialized()
                            val initMs = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "initialized" to true,
                                        "isColdInit" to wasCold,
                                        "coldInitMs" to initMs.toInt()
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            Log.w(TAG_CASCADE, "initialize failed: ${e.message}")
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "initialized" to false,
                                        "error" to (e.message ?: "Failed to initialize SigLIP session")
                                    )
                                )
                            }
                        }
                    }
                }
                "recognizeImageBytes" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    if (imageBytes == null || imageBytes.isEmpty()) {
                        result.success(
                            mapOf(
                                "isUnavailable" to true,
                                "errorReason" to "Empty imageBytes passed to recognizeImageBytes."
                            )
                        )
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val response = recognizeImageBytesInternal(imageBytes)
                            mainHandler.post { result.success(response) }
                        } catch (e: Exception) {
                            Log.e(TAG_CASCADE, "recognizeImageBytes error", e)
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "isUnavailable" to true,
                                        "errorReason" to (e.message ?: "Open-vocab inference exception")
                                    )
                                )
                            }
                        }
                    }
                }
                "dispose" -> {
                    executor.execute {
                        disposeSessionInternal()
                        mainHandler.post { result.success(null) }
                    }
                }
                "getValidationConfig" -> {
                    val valDir = getExternalFilesDir("validation_images")
                    if (valDir != null && !valDir.exists()) {
                        valDir.mkdirs()
                    }
                    val shouldRun = intent?.getStringExtra("validate_35_11b") == "true"
                    val mode = intent?.getStringExtra("validate_mode") ?: "online"
                    result.success(
                        mapOf(
                            "shouldRun" to shouldRun,
                            "mode" to mode,
                            "validationDir" to (valDir?.absolutePath ?: "")
                        )
                    )
                }
                "getDeviceDiagnostics" -> {
                    executor.execute {
                        val diag = getDeviceDiagnosticsInternal()
                        mainHandler.post { result.success(diag) }
                    }
                }
                "registerDynamicVocabularyPack" -> {
                    val packId = call.argument<String>("packId") ?: ""
                    val version = call.argument<String>("version") ?: ""
                    val targetModelId = call.argument<String>("targetModelId") ?: "siglip_b16_int8"
                    val requireAllVision = call.argument<Boolean>("requireAllVisionEligible") ?: false
                    val entries = call.argument<List<Map<String, Any?>>>("entries") ?: emptyList()

                    executor.execute {
                        try {
                            ensureSessionInitialized()
                            val response = registerDynamicVocabularyPackInternal(
                                packId, version, targetModelId, requireAllVision, entries
                            )
                            mainHandler.post { result.success(response) }
                        } catch (e: Exception) {
                            Log.e(TAG_CASCADE, "registerDynamicVocabularyPack error", e)
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "success" to false,
                                        "error" to (e.message ?: "Failed to register vocabulary pack"),
                                        "rolledBack" to true
                                    )
                                )
                            }
                        }
                    }
                }
                "clearDynamicVocabulary" -> {
                    executor.execute {
                        try {
                            val response = clearDynamicVocabularyInternal()
                            mainHandler.post { result.success(response) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.success(mapOf("success" to false, "error" to (e.message ?: "Failed to clear dynamic vocabulary")))
                            }
                        }
                    }
                }
                "getRegisteredVocabularyInfo" -> {
                    executor.execute {
                        try {
                            ensureSessionInitialized()
                            val total = (activeCanonicalEmbeds?.size ?: 0) / EMBED_DIM
                            val base = 2050
                            val dynamic = maxOf(0, total - base)
                            val packsFile = getDynamicPacksFile()
                            val packsCount = if (packsFile.exists()) {
                                try { JSONArray(packsFile.readText()).length() } catch (_: Exception) { 0 }
                            } else 0
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "totalConcepts" to total,
                                        "baseConcepts" to base,
                                        "dynamicConcepts" to dynamic,
                                        "dynamicPacksCount" to packsCount
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "totalConcepts" to 0,
                                        "baseConcepts" to 2050,
                                        "dynamicConcepts" to 0,
                                        "error" to (e.message ?: "Failed to get vocabulary info")
                                    )
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun round2(v: Double): Double = (v * 100.0).roundToInt() / 100.0

    private fun getDeviceDiagnosticsInternal(): Map<String, Any> {
        val memInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memInfo)
        val totalPssMb = memInfo.totalPss / 1024.0
        val nativeHeapMb = Debug.getNativeHeapAllocatedSize() / (1024.0 * 1024.0)
        var vmRssMb = 0.0
        try {
            val statusLines = File("/proc/self/status").readLines()
            for (line in statusLines) {
                if (line.startsWith("VmRSS:")) {
                    val kb = line.replace("VmRSS:", "").replace("kB", "").trim().toLongOrNull() ?: 0L
                    vmRssMb = kb / 1024.0
                }
            }
        } catch (_: Exception) {
        }

        var netActive = false
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val net = cm?.activeNetwork
            val caps = if (net != null) cm.getNetworkCapabilities(net) else null
            if (caps != null) {
                netActive = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
            }
        } catch (_: Throwable) {
        }

        return mapOf(
            "pssMb" to round2(totalPssMb),
            "rssMb" to round2(vmRssMb),
            "nativeHeapMb" to round2(nativeHeapMb),
            "networkActive" to netActive,
            "sessionLoaded" to (activeSession != null),
            "deviceModel" to Build.MODEL,
            "sdkInt" to Build.VERSION.SDK_INT,
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
        )
    }

    private fun checkAssetsAvailableInternal(): Boolean {
        val internalDir = File(filesDir, "openvocab")
        if (File(internalDir, VISION_MODEL_FILE).exists() &&
            File(internalDir, TEXT_INDEX_FILE).exists() &&
            File(internalDir, NEG_INDEX_FILE).exists() &&
            File(internalDir, VOCAB_JSON_FILE).exists()
        ) {
            return true
        }
        return try {
            val list = assets.list("openvocab") ?: emptyArray()
            list.contains(VISION_MODEL_FILE) &&
                list.contains(TEXT_INDEX_FILE) &&
                list.contains(NEG_INDEX_FILE) &&
                list.contains(VOCAB_JSON_FILE)
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveOrExtractAssetsInternal(): Map<String, Any> {
        val targetDir = File(filesDir, "openvocab")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        val requiredFiles = listOf(
            VISION_MODEL_FILE,
            TEXT_INDEX_FILE,
            NEG_INDEX_FILE,
            VOCAB_JSON_FILE
        )

        for (fileName in requiredFiles) {
            val outFile = File(targetDir, fileName)
            if (!outFile.exists() || outFile.length() == 0L) {
                assets.open("openvocab/$fileName").use { input ->
                    FileOutputStream(outFile).use { output ->
                        val buffer = ByteArray(256 * 1024)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                        }
                        output.flush()
                    }
                }
            }
        }

        val modelFile = File(targetDir, VISION_MODEL_FILE)
        val textFile = File(targetDir, TEXT_INDEX_FILE)
        val negFile = File(targetDir, NEG_INDEX_FILE)
        val vocabFile = File(targetDir, VOCAB_JSON_FILE)

        val valid = modelFile.exists() && modelFile.length() > 1_000_000L &&
            textFile.exists() && textFile.length() > 100_000L &&
            negFile.exists() && negFile.length() > 1_000L &&
            vocabFile.exists() && vocabFile.length() > 10_000L

        return mapOf(
            "available" to valid,
            "visionModelPath" to modelFile.absolutePath,
            "textIndexPath" to textFile.absolutePath,
            "negIndexPath" to negFile.absolutePath,
            "vocabJsonPath" to vocabFile.absolutePath
        )
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

    private fun ensureSessionInitialized(): Double {
        if (activeSession != null &&
            activeCanonicalEmbeds != null &&
            activeNegativeEmbeds != null &&
            vocabConcepts != null
        ) {
            return 0.0
        }

        val t0 = SystemClock.elapsedRealtimeNanos()
        val resolved = resolveOrExtractAssetsInternal()
        if (resolved["available"] != true) {
            throw IllegalStateException("SigLIP open-vocabulary assets are missing or corrupt.")
        }

        val modelPath = resolved["visionModelPath"] as String
        val textPath = resolved["textIndexPath"] as String
        val negPath = resolved["negIndexPath"] as String
        val vocabPath = resolved["vocabJsonPath"] as String

        if (ortEnv == null) {
            ortEnv = OrtEnvironment.getEnvironment()
        }
        val opts = OrtSession.SessionOptions().apply {
            setIntraOpNumThreads(4)
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        }
        activeSession = ortEnv!!.createSession(modelPath, opts)
        activeCanonicalEmbeds = loadFp16BinaryToFloatArray(File(textPath))
        activeNegativeEmbeds = loadFp16BinaryToFloatArray(File(negPath))

        val vocabRoot = JSONObject(File(vocabPath).readText(Charsets.UTF_8))
        vocabConcepts = vocabRoot.getJSONArray("concepts")
        negativeLabels = vocabRoot.getJSONArray("negativeLabels")
        thresholdsJson = vocabRoot.getJSONObject("thresholds")

        loadAndApplyPersistedDynamicPacks()

        val coldInitMs = (SystemClock.elapsedRealtimeNanos() - t0) / 1_000_000.0
        Log.i(
            TAG_PERF,
            "[FoodScanLocalPerf] tier2_cold_init_ms=${coldInitMs.toInt()} provider=\"$activeExecutionProvider\""
        )
        return coldInitMs
    }

    private fun getDynamicPacksFile(): File = File(File(filesDir, "openvocab"), DYNAMIC_VOCAB_FILE)

    private fun loadAndApplyPersistedDynamicPacks() {
        val file = getDynamicPacksFile()
        if (!file.exists() || file.length() == 0L) return
        try {
            val content = file.readText(Charsets.UTF_8)
            val jsonArray = JSONArray(content)
            var totalRestored = 0
            for (p in 0 until jsonArray.length()) {
                val packObj = jsonArray.getJSONObject(p)
                val entriesArray = packObj.optJSONArray("entries") ?: continue
                totalRestored += applyPackEntriesToActiveState(packObj.optString("packId", ""), entriesArray)
            }
            Log.i(TAG_CASCADE, "[DynamicVocab] Restored dynamic packs from disk. Added concepts=$totalRestored Total concepts=${vocabConcepts?.length() ?: 0}")
        } catch (e: Exception) {
            Log.w(TAG_CASCADE, "[DynamicVocab] Failed to restore dynamic packs: ${e.message}")
        }
    }

    private fun applyPackEntriesToActiveState(packId: String, entriesArray: JSONArray): Int {
        val currentEmbeds = activeCanonicalEmbeds ?: return 0
        val currentConcepts = vocabConcepts ?: return 0

        val validEmbedsList = mutableListOf<FloatArray>()
        val validConceptsList = mutableListOf<JSONObject>()

        val existingIds = mutableSetOf<String>()
        for (i in 0 until currentConcepts.length()) {
            existingIds.add(currentConcepts.getJSONObject(i).getString("id"))
        }

        for (i in 0 until entriesArray.length()) {
            val item = entriesArray.getJSONObject(i)
            val id = item.optString("id", "").trim()
            val name = item.optString("name", "").trim()
            if (id.isEmpty() || name.isEmpty() || existingIds.contains(id)) {
                continue
            }
            val embArray = item.optJSONArray("embedding")
            if (embArray != null && embArray.length() == EMBED_DIM) {
                val floatVec = FloatArray(EMBED_DIM)
                var hasInvalid = false
                var normSq = 0.0f
                for (d in 0 until EMBED_DIM) {
                    val v = embArray.getDouble(d).toFloat()
                    if (v.isNaN() || v.isInfinite()) {
                        hasInvalid = true
                        break
                    }
                    floatVec[d] = v
                    normSq += v * v
                }
                if (!hasInvalid) {
                    val invNorm = if (normSq > 1e-12f) (1.0f / sqrt(normSq)) else 1.0f
                    for (d in 0 until EMBED_DIM) {
                        floatVec[d] *= invNorm
                    }
                    validEmbedsList.add(floatVec)

                    val conceptObj = JSONObject().apply {
                        put("id", id)
                        put("name", name)
                        put("cat", item.optString("cat", ""))
                        put("inFitFuel238", item.optBoolean("inFitFuel238", false))
                        put("dynamicPackId", packId)
                    }
                    validConceptsList.add(conceptObj)
                    existingIds.add(id)
                }
            }
        }

        if (validEmbedsList.isEmpty()) return 0

        val newTotalEmbeds = FloatArray(currentEmbeds.size + validEmbedsList.size * EMBED_DIM)
        System.arraycopy(currentEmbeds, 0, newTotalEmbeds, 0, currentEmbeds.size)
        var offset = currentEmbeds.size
        for (vec in validEmbedsList) {
            System.arraycopy(vec, 0, newTotalEmbeds, offset, EMBED_DIM)
            offset += EMBED_DIM
        }

        val newConcepts = JSONArray()
        for (i in 0 until currentConcepts.length()) {
            newConcepts.put(currentConcepts.get(i))
        }
        for (c in validConceptsList) {
            newConcepts.put(c)
        }

        activeCanonicalEmbeds = newTotalEmbeds
        vocabConcepts = newConcepts
        return validEmbedsList.size
    }

    private fun registerDynamicVocabularyPackInternal(
        packId: String,
        version: String,
        targetModelId: String,
        requireAllVision: Boolean,
        entries: List<Map<String, Any?>>
    ): Map<String, Any?> {
        if (packId.trim().isEmpty()) {
            return mapOf("success" to false, "error" to "Pack ID cannot be empty", "rolledBack" to true)
        }
        if (version.trim().isEmpty()) {
            return mapOf("success" to false, "error" to "Pack version cannot be empty", "rolledBack" to true)
        }
        if (entries.isEmpty()) {
            return mapOf("success" to false, "error" to "Pack entries list is empty", "rolledBack" to true)
        }

        if (requireAllVision && !targetModelId.lowercase(Locale.ROOT).contains("siglip")) {
            return mapOf(
                "success" to false,
                "error" to "Incompatible model ID '$targetModelId'. Expected SigLIP model compatible with '$MODEL_VERSION'.",
                "rolledBack" to true
            )
        }

        val previousEmbeds = activeCanonicalEmbeds
        val previousConcepts = vocabConcepts
            ?: throw IllegalStateException("Vocab concepts not initialized")

        // Prune previous entries for this packId if re-registering or updating
        var currentEmbeds = previousEmbeds
        var currentConcepts = previousConcepts
        val oldPackIndices = mutableListOf<Int>()
        for (i in 0 until currentConcepts.length()) {
            val c = currentConcepts.getJSONObject(i)
            if (c.optString("dynamicPackId") == packId) {
                oldPackIndices.add(i)
            }
        }

        if (oldPackIndices.isNotEmpty() && currentEmbeds != null) {
            val oldSet = oldPackIndices.toSet()
            val keptConcepts = JSONArray()
            val keptEmbeds = FloatArray(currentEmbeds.size - oldSet.size * EMBED_DIM)
            var keptOffset = 0
            for (i in 0 until currentConcepts.length()) {
                if (!oldSet.contains(i)) {
                    keptConcepts.put(currentConcepts.getJSONObject(i))
                    System.arraycopy(currentEmbeds, i * EMBED_DIM, keptEmbeds, keptOffset, EMBED_DIM)
                    keptOffset += EMBED_DIM
                }
            }
            activeCanonicalEmbeds = keptEmbeds
            vocabConcepts = keptConcepts
            currentEmbeds = keptEmbeds
            currentConcepts = keptConcepts
        }

        val existingIds = mutableSetOf<String>()
        for (i in 0 until currentConcepts.length()) {
            existingIds.add(currentConcepts.getJSONObject(i).getString("id"))
        }

        val packJsonEntries = JSONArray()
        val incomingIdsInPack = mutableSetOf<String>()

        for (raw in entries) {
            val id = (raw["canonicalFoodId"] as? String ?: "").trim()
            val name = (raw["canonicalName"] as? String ?: "").trim()
            val cat = (raw["category"] as? String ?: "").trim()
            val inFitFuel238 = (raw["inFitFuel238"] as? Boolean) ?: false

            if (id.isEmpty()) {
                activeCanonicalEmbeds = previousEmbeds
                vocabConcepts = previousConcepts
                return mapOf("success" to false, "error" to "Entry with empty canonicalFoodId", "rolledBack" to true)
            }
            if (name.isEmpty()) {
                activeCanonicalEmbeds = previousEmbeds
                vocabConcepts = previousConcepts
                return mapOf("success" to false, "error" to "Entry '$id' has empty canonicalName", "rolledBack" to true)
            }
            if (incomingIdsInPack.contains(id)) {
                activeCanonicalEmbeds = previousEmbeds
                vocabConcepts = previousConcepts
                return mapOf("success" to false, "error" to "Duplicate food ID '$id' in pack", "rolledBack" to true)
            }
            incomingIdsInPack.add(id)

            if (existingIds.contains(id)) {
                activeCanonicalEmbeds = previousEmbeds
                vocabConcepts = previousConcepts
                return mapOf("success" to false, "error" to "Food ID '$id' already exists in active vocabulary", "rolledBack" to true)
            }

            @Suppress("UNCHECKED_CAST")
            val rawEmbedding = raw["textEmbedding"] as? List<Any?>

            val entryJson = JSONObject().apply {
                put("id", id)
                put("name", name)
                put("cat", cat)
                put("inFitFuel238", inFitFuel238)
            }

            if (rawEmbedding != null) {
                if (rawEmbedding.size != EMBED_DIM) {
                    if (requireAllVision) {
                        activeCanonicalEmbeds = previousEmbeds
                        vocabConcepts = previousConcepts
                        return mapOf(
                            "success" to false,
                            "error" to "Entry '$id' embedding length is ${rawEmbedding.size}, expected $EMBED_DIM",
                            "rolledBack" to true
                        )
                    }
                } else {
                    val embArray = JSONArray()
                    var hasInvalid = false
                    var normSq = 0.0
                    for (item in rawEmbedding) {
                        val num = (item as? Number)?.toDouble() ?: Double.NaN
                        if (num.isNaN() || num.isInfinite()) {
                            hasInvalid = true
                            break
                        }
                        normSq += num * num
                        embArray.put(num)
                    }
                    if (hasInvalid) {
                        if (requireAllVision) {
                            activeCanonicalEmbeds = previousEmbeds
                            vocabConcepts = previousConcepts
                            return mapOf(
                                "success" to false,
                                "error" to "Entry '$id' embedding contains NaN or Infinite values",
                                "rolledBack" to true
                            )
                        }
                    } else if (normSq < 1e-12) {
                        if (requireAllVision) {
                            activeCanonicalEmbeds = previousEmbeds
                            vocabConcepts = previousConcepts
                            return mapOf(
                                "success" to false,
                                "error" to "Entry '$id' embedding has zero or near-zero norm ($normSq)",
                                "rolledBack" to true
                            )
                        }
                    } else {
                        entryJson.put("embedding", embArray)
                    }
                }
            } else if (requireAllVision) {
                activeCanonicalEmbeds = previousEmbeds
                vocabConcepts = previousConcepts
                return mapOf(
                    "success" to false,
                    "error" to "Entry '$id' lacks text embedding under requireAllVisionEligible mode",
                    "rolledBack" to true
                )
            }

            packJsonEntries.put(entryJson)
        }

        // Apply to in-memory state
        val addedCount = applyPackEntriesToActiveState(packId, packJsonEntries)

        // Persist to disk atomically
        try {
            val packsFile = getDynamicPacksFile()
            val existingPacksArray = if (packsFile.exists() && packsFile.length() > 0) {
                try {
                    JSONArray(packsFile.readText(Charsets.UTF_8))
                } catch (_: Exception) {
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            val updatedPacksArray = JSONArray()
            for (p in 0 until existingPacksArray.length()) {
                val pObj = existingPacksArray.getJSONObject(p)
                if (pObj.optString("packId") != packId) {
                    updatedPacksArray.put(pObj)
                }
            }
            val newPackObj = JSONObject().apply {
                put("packId", packId)
                put("version", version)
                put("targetModelId", targetModelId)
                put("entries", packJsonEntries)
            }
            updatedPacksArray.put(newPackObj)

            val tmpFile = File(packsFile.parentFile, "$DYNAMIC_VOCAB_FILE.tmp")
            FileOutputStream(tmpFile).use { out ->
                out.write(updatedPacksArray.toString(2).toByteArray(Charsets.UTF_8))
                out.flush()
            }
            if (!tmpFile.renameTo(packsFile)) {
                tmpFile.copyTo(packsFile, overwrite = true)
                tmpFile.delete()
            }
            Log.i(TAG_CASCADE, "[DynamicVocab] Atomically saved pack '$packId' to disk.")
        } catch (e: Exception) {
            Log.e(TAG_CASCADE, "[DynamicVocab] Failed to persist pack to disk", e)
        }

        return mapOf(
            "success" to true,
            "packId" to packId,
            "visionAddedCount" to addedCount,
            "totalConcepts" to ((activeCanonicalEmbeds?.size ?: 0) / EMBED_DIM),
            "persisted" to true
        )
    }

    private fun clearDynamicVocabularyInternal(): Map<String, Any> {
        val file = getDynamicPacksFile()
        if (file.exists()) {
            file.delete()
        }
        val resolved = resolveOrExtractAssetsInternal()
        val textPath = resolved["textIndexPath"] as String
        val vocabPath = resolved["vocabJsonPath"] as String
        activeCanonicalEmbeds = loadFp16BinaryToFloatArray(File(textPath))
        val vocabRoot = JSONObject(File(vocabPath).readText(Charsets.UTF_8))
        vocabConcepts = vocabRoot.getJSONArray("concepts")
        Log.i(TAG_CASCADE, "[DynamicVocab] Cleared dynamic vocabulary. Reset to ${vocabConcepts?.length() ?: 0} base concepts.")
        return mapOf(
            "success" to true,
            "totalConcepts" to ((activeCanonicalEmbeds?.size ?: 0) / EMBED_DIM)
        )
    }

    private fun decodeAndOrientBitmap(imageBytes: ByteArray): Bitmap {
        val opts = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val rawBitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, opts)
            ?: throw IllegalArgumentException("Failed to decode image bytes.")

        val orientation = try {
            val exif = ExifInterface(ByteArrayInputStream(imageBytes))
            exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }

        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            else -> return rawBitmap
        }

        val oriented = Bitmap.createBitmap(
            rawBitmap,
            0,
            0,
            rawBitmap.width,
            rawBitmap.height,
            matrix,
            true
        )
        if (oriented !== rawBitmap && !rawBitmap.isRecycled) {
            rawBitmap.recycle()
        }
        return oriented
    }

    private fun preprocessBitmapToSiglipFloatBuffer(bmp: Bitmap): FloatBuffer {
        val w = bmp.width
        val h = bmp.height
        val side = min(w, h)
        val left = (w - side) / 2
        val top = (h - side) / 2

        val cropped = Bitmap.createBitmap(bmp, left, top, side, side)
        val scaled = if (side == 224) {
            cropped
        } else {
            Bitmap.createScaledBitmap(cropped, 224, 224, true)
        }

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

        // SigLIP normalization: mean = [0.5, 0.5, 0.5], std = [0.5, 0.5, 0.5] -> [-1.0, 1.0]
        for (i in 0 until planeSize) {
            val px = pixels[i]
            floatArray[i] = ((px shr 16) and 0xFF) / 127.5f - 1.0f
            floatArray[planeSize + i] = ((px shr 8) and 0xFF) / 127.5f - 1.0f
            floatArray[2 * planeSize + i] = (px and 0xFF) / 127.5f - 1.0f
        }

        return FloatBuffer.wrap(floatArray)
    }

    private fun recognizeImageBytesInternal(imageBytes: ByteArray): Map<String, Any?> {
        val wasCold = activeSession == null
        val coldInitMs = if (wasCold) ensureSessionInitialized() else 0.0

        val session = activeSession!!
        val env = ortEnv!!
        val canonMat = activeCanonicalEmbeds!!
        val negMat = activeNegativeEmbeds!!
        val concepts = vocabConcepts!!
        val negLabels = negativeLabels!!
        val thrObj = thresholdsJson?.optJSONObject(MODEL_VERSION)

        val modeAThreshold = thrObj?.optDouble("modeA_sim_threshold", 0.0665) ?: 0.0665
        val modeBFloor = thrObj?.optDouble("modeB_sim_floor", 0.0181) ?: 0.0181
        val modeBMargin = thrObj?.optDouble("modeB_neg_margin_threshold", 0.0621) ?: 0.0621

        // 1. Preprocess
        val tPre0 = SystemClock.elapsedRealtimeNanos()
        val bmp = decodeAndOrientBitmap(imageBytes)
        val floatBuf = preprocessBitmapToSiglipFloatBuffer(bmp)
        if (!bmp.isRecycled) {
            bmp.recycle()
        }
        val preprocessMs = (SystemClock.elapsedRealtimeNanos() - tPre0) / 1_000_000.0

        // 2. Vision Encoder Inference + L2 Normalization
        val tEnc0 = SystemClock.elapsedRealtimeNanos()
        val shape = longArrayOf(1L, 3L, 224L, 224L)
        val inputTensor = OnnxTensor.createTensor(env, floatBuf, shape)
        val emb = FloatArray(EMBED_DIM)
        try {
            val ortOutputs = session.run(mapOf("pixel_values" to inputTensor))
            try {
                val outVal = ortOutputs[0].value
                @Suppress("UNCHECKED_CAST")
                val rawRow = (outVal as Array<FloatArray>)[0]
                var normSq = 0.0f
                for (d in 0 until EMBED_DIM) {
                    val v = rawRow[d]
                    normSq += v * v
                }
                val invNorm = if (normSq > 1e-12f) (1.0f / sqrt(normSq)) else 1.0f
                for (d in 0 until EMBED_DIM) {
                    emb[d] = rawRow[d] * invNorm
                }
            } finally {
                ortOutputs.close()
            }
        } finally {
            inputTensor.close()
        }
        val encoderMs = (SystemClock.elapsedRealtimeNanos() - tEnc0) / 1_000_000.0

        // 3. Retrieval over 2,050 canonical food concepts + 12 negative non-food prompts
        val tRet0 = SystemClock.elapsedRealtimeNanos()
        val numConcepts = canonMat.size / EMBED_DIM
        val topK = 10
        val topIdx = IntArray(topK) { -1 }
        val topVal = FloatArray(topK) { -Float.MAX_VALUE }

        for (c in 0 until numConcepts) {
            val offset = c * EMBED_DIM
            var dot = 0.0f
            for (d in 0 until EMBED_DIM) {
                dot += canonMat[offset + d] * emb[d]
            }
            if (dot > topVal[topK - 1]) {
                var pos = topK - 1
                while (pos > 0 && dot > topVal[pos - 1]) {
                    topVal[pos] = topVal[pos - 1]
                    topIdx[pos] = topIdx[pos - 1]
                    pos--
                }
                topVal[pos] = dot
                topIdx[pos] = c
            }
        }

        val numNeg = negMat.size / EMBED_DIM
        var maxNegSim = -Float.MAX_VALUE
        var maxNegIdx = 0
        for (n in 0 until numNeg) {
            val offset = n * EMBED_DIM
            var dot = 0.0f
            for (d in 0 until EMBED_DIM) {
                dot += negMat[offset + d] * emb[d]
            }
            if (dot > maxNegSim) {
                maxNegSim = dot
                maxNegIdx = n
            }
        }

        val maxFoodSim = topVal[0].toDouble()
        val negMargin = maxFoodSim - maxNegSim.toDouble()
        val acceptedModeA = maxFoodSim >= modeAThreshold
        val acceptedModeB = (maxFoodSim >= modeBFloor) && (negMargin >= modeBMargin)
        val foodAccepted = acceptedModeA && acceptedModeB
        val abstained = !foodAccepted

        val retrievalMs = (SystemClock.elapsedRealtimeNanos() - tRet0) / 1_000_000.0
        val totalMs = preprocessMs + encoderMs + retrievalMs

        val candidateList = mutableListOf<Map<String, Any?>>()
        val top3Names = mutableListOf<String>()
        for (k in 0 until topK) {
            val idx = topIdx[k]
            if (idx < 0 || idx >= concepts.length()) continue
            val cObj = concepts.getJSONObject(idx)
            val cId = cObj.getString("id")
            val cName = cObj.getString("name")
            val cCat = cObj.optString("cat", "")
            val inFitFuel238 = cObj.optBoolean("inFitFuel238", false)
            if (k < 3) {
                top3Names.add(cName)
            }
            candidateList.add(
                mapOf(
                    "canonicalFoodId" to cId,
                    "canonicalName" to cName,
                    "category" to cCat,
                    "similarity" to topVal[k].toDouble(),
                    "rank" to (k + 1),
                    "inFitFuelCatalog" to inFitFuel238,
                    "fitFuelFoodId" to (if (inFitFuel238) cId else null)
                )
            )
        }

        val topNegativePrompt = negLabels.optString(maxNegIdx, "")
        val abstainReason = if (!foodAccepted) {
            if (negMargin < modeBMargin) "non_food_negative_margin" else "below_similarity_threshold"
        } else {
            null
        }

        Log.i(
            TAG_PERF,
            "[FoodScanLocalPerf] tier2_cold_init_ms=${coldInitMs.toInt()} " +
                "tier2_preprocess_ms=${preprocessMs.toInt()} " +
                "tier2_encoder_ms=${encoderMs.toInt()} " +
                "tier2_retrieval_ms=${retrievalMs.toInt()} " +
                "tier2_total_ms=${totalMs.toInt()}"
        )
        Log.i(
            TAG_CASCADE,
            "[FoodScanCascade] tier2_model=$MODEL_VERSION " +
                "top1=\"${top3Names.firstOrNull() ?: "none"}\" " +
                "top3=\"${top3Names.joinToString(" | ")}\" " +
                "food_sim=${String.format(Locale.US, "%.4f", maxFoodSim)} " +
                "neg_sim=${String.format(Locale.US, "%.4f", maxNegSim.toDouble())} " +
                "neg_margin=${String.format(Locale.US, "%.4f", negMargin)} " +
                "food_accepted=$foodAccepted cloud_calls=0"
        )

        return mapOf(
            "isAvailable" to true,
            "foodAccepted" to foodAccepted,
            "abstained" to abstained,
            "abstainReason" to abstainReason,
            "maxFoodSimilarity" to maxFoodSim,
            "maxNegSimilarity" to maxNegSim.toDouble(),
            "negMargin" to negMargin,
            "topNegativePrompt" to topNegativePrompt,
            "isColdInit" to wasCold,
            "coldInitMs" to coldInitMs.toInt(),
            "preprocessMs" to preprocessMs.toInt(),
            "encoderMs" to encoderMs.toInt(),
            "retrievalMs" to retrievalMs.toInt(),
            "totalMs" to totalMs.toInt(),
            "executionProvider" to activeExecutionProvider,
            "modelVersion" to MODEL_VERSION,
            "topCandidates" to candidateList
        )
    }

    private fun disposeSessionInternal() {
        val hadSession = activeSession != null
        try {
            activeSession?.close()
        } catch (_: Exception) {
        }
        activeSession = null
        activeCanonicalEmbeds = null
        activeNegativeEmbeds = null
        System.gc()
        if (hadSession) {
            Log.i(TAG_CASCADE, "[FoodScanCascade] tier2_session_disposed model=$MODEL_VERSION")
        }
    }

    override fun onDestroy() {
        disposeSessionInternal()
        super.onDestroy()
    }
}
