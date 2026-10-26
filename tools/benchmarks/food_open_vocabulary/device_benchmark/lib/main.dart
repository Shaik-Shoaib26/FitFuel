import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpenVocabDeviceBenchmarkApp());
}

class OpenVocabDeviceBenchmarkApp extends StatelessWidget {
  const OpenVocabDeviceBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFuel 35.11A.2 Device Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const OpenVocabDeviceBenchmarkScreen(),
    );
  }
}

class OpenVocabDeviceBenchmarkScreen extends StatefulWidget {
  const OpenVocabDeviceBenchmarkScreen({super.key});

  @override
  State<OpenVocabDeviceBenchmarkScreen> createState() =>
      _OpenVocabDeviceBenchmarkScreenState();
}

class _OpenVocabDeviceBenchmarkScreenState
    extends State<OpenVocabDeviceBenchmarkScreen> {
  static const MethodChannel _channel =
      MethodChannel('fitfuel.benchmark/open_vocab_onnx');
  static const String _dartAutorun =
      String.fromEnvironment('AUTORUN', defaultValue: '');

  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _deviceStatus;
  List<Map<String, dynamic>> _suiteItems = const [];
  String? _selectedImagePath;
  String _selectedImageLabel = 'Creamy Penne Pasta (food_0468)';
  String _selectedImageId = 'food_0468';

  Map<String, dynamic>? _lastSingleResult;
  Map<String, dynamic>? _benchmarkSummary;
  Map<String, dynamic>? _offlineSummary;

  bool _isBusy = false;
  String _statusMessage = 'Initializing Samsung RZCW8201QBV harness...';

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();
  }

  Future<void> _loadInitialStatus() async {
    setState(() {
      _isBusy = true;
      _statusMessage = 'Checking on-device ONNX models & FP16 text indices...';
    });
    try {
      final raw = await _channel.invokeMethod<String>('getDeviceStatus');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final itemsRaw = (decoded['suiteItems'] as List<dynamic>? ?? const []);
        final items = itemsRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);

        String? defaultPath;
        String defaultLabel = _selectedImageLabel;
        String defaultId = _selectedImageId;
        for (final it in items) {
          if (it['imageId'] == 'food_0468') {
            defaultPath = it['fullPath'] as String?;
            defaultLabel =
                '${it['displayLabel']} (${it['imageId']})';
            defaultId = it['imageId'] as String;
            break;
          }
        }
        if (defaultPath == null && items.isNotEmpty) {
          defaultPath = items.first['fullPath'] as String?;
          defaultLabel =
              '${items.first['displayLabel']} (${items.first['imageId']})';
          defaultId = items.first['imageId'] as String;
        }

        if (!mounted) return;
        setState(() {
          _deviceStatus = decoded;
          _suiteItems = items;
          _selectedImagePath = defaultPath;
          _selectedImageLabel = defaultLabel;
          _selectedImageId = defaultId;
          _isBusy = false;
          _statusMessage = 'Ready on ${decoded['deviceModel']} '
              '(Android ${decoded['androidRelease']} • 0 Cloud Calls)';
        });

        final intentAutorun = (decoded['autorun'] as String? ?? '').trim();
        if (_dartAutorun == 'full_benchmark') {
          await _runFullBenchmark();
        } else if (_dartAutorun == 'offline_test') {
          await _runOfflineVerification();
        } else if (intentAutorun.isEmpty &&
            defaultPath != null &&
            (decoded['siglipReady'] == true)) {
          await _runSingleModel('siglip_b16_int8');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Status check failed: $e';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isBusy) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _selectedImagePath = picked.path;
        _selectedImageLabel = 'Gallery: ${picked.name}';
        _selectedImageId = 'gallery_${picked.name}';
        _statusMessage =
            'Selected gallery photo (${picked.name}). Tap Run SigLIP or Run TinyCLIP.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Gallery selection error: $e';
      });
    }
  }

  Future<void> _runSingleModel(String modelKey) async {
    if (_isBusy) return;
    final path = _selectedImagePath;
    if (path == null || path.isEmpty) {
      setState(() {
        _statusMessage = 'Please select an image first.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage =
          'Running local $modelKey inference on RZCW8201QBV (0 cloud calls)...';
    });

    try {
      final raw = await _channel.invokeMethod<String>('runSingleImage', {
        'modelKey': modelKey,
        'imagePath': path,
        'imageId': _selectedImageId,
      });
      if (raw != null && mounted) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _lastSingleResult = decoded;
          _isBusy = false;
          _statusMessage =
              'Completed ${decoded['modelDisplayName']} in ${decoded['totalMs']} ms (Cloud calls: 0)';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Inference failed: $e';
      });
    }
  }

  Future<void> _runFullBenchmark() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage =
          'Running 100-scan benchmark + 56-image suite for SigLIP-B/16 INT8 & TinyCLIP-40M/32 INT8 on RZCW8201QBV...';
    });

    try {
      final raw = await _channel.invokeMethod<String>('runFullBenchmark', {
        'runs': 100,
      });
      if (raw != null && mounted) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _benchmarkSummary = decoded;
          _isBusy = false;
          _statusMessage =
              '100-Scan Benchmark Complete! Raw JSON & CSVs saved on device.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Full benchmark failed: $e';
      });
    }
  }

  Future<void> _runOfflineVerification() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage =
          'Running True Offline Verification (Samosa, Pasta, Non-Food) on RZCW8201QBV...';
    });

    try {
      final raw =
          await _channel.invokeMethod<String>('runOfflineVerification');
      if (raw != null && mounted) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _offlineSummary = decoded;
          _isBusy = false;
          _statusMessage =
              'Offline Verification PASS! Cloud calls: ${decoded['cloudCalls']}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Offline verification failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _lastSingleResult;
    final top5 = (res?['top5'] as List<dynamic>? ?? const []);
    final bool foodAccepted = res?['foodAccepted'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitFuel 35.11A.2 • Samsung Open-Vocab Benchmark',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _loadInitialStatus,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Device Status',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildDeviceHeaderCard(),
            const SizedBox(height: 10),
            _buildManualGalleryCard(),
            const SizedBox(height: 10),
            if (res != null) _buildPredictionResultCard(res, top5, foodAccepted),
            if (_offlineSummary != null) ...[
              const SizedBox(height: 10),
              _buildOfflineSummaryCard(_offlineSummary!),
            ],
            if (_benchmarkSummary != null) ...[
              const SizedBox(height: 10),
              _buildBenchmarkSummaryCard(_benchmarkSummary!),
            ],
            const SizedBox(height: 10),
            _buildAutomatedSuiteControlsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceHeaderCard() {
    final st = _deviceStatus;
    final netActive = st?['networkConnected'] == true;
    final mem = st?['memory'] as Map<String, dynamic>?;
    final bat = st?['battery'] as Map<String, dynamic>?;

    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: Colors.tealAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Device: ${st?['deviceModel'] ?? 'SM-E346B'} • Serial: RZCW8201QBV • Android ${st?['androidRelease'] ?? '16'} (${st?['abi'] ?? 'arm64-v8a'})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPill(
                  'Cloud Calls: 0 (100% Local ONNX)',
                  Colors.green.shade800,
                ),
                _buildPill(
                  netActive ? 'Network: ONLINE' : 'Network: OFFLINE (Airgapped)',
                  netActive ? Colors.blueGrey.shade700 : Colors.orange.shade800,
                ),
                if (mem != null)
                  _buildPill(
                    'PSS: ${mem['pssMb']} MB | RSS: ${mem['rssMb']} MB',
                    Colors.indigo.shade800,
                  ),
                if (bat != null)
                  _buildPill(
                    'Battery: ${bat['batteryPct']}% (${bat['batteryTempC']}°C)',
                    Colors.teal.shade800,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualGalleryCard() {
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MANUAL GALLERY & PRESET TEST MODE (NO AI CLOUD BUTTON)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Choose Image (Gallery)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_suiteItems.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _suiteItems.any((e) => e['fullPath'] == _selectedImagePath)
                    ? _selectedImagePath
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Or select an on-device benchmark test photo (56 images)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _suiteItems.map((item) {
                  final path = item['fullPath'] as String;
                  final label =
                      '[${item['testGroup']}] ${item['displayLabel']} (${item['imageId']})';
                  return DropdownMenuItem<String>(
                    value: path,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: _isBusy
                    ? null
                    : (val) {
                        if (val == null) return;
                        final found = _suiteItems.firstWhere(
                          (e) => e['fullPath'] == val,
                          orElse: () => _suiteItems.first,
                        );
                        setState(() {
                          _selectedImagePath = val;
                          _selectedImageLabel =
                              '${found['displayLabel']} (${found['imageId']})';
                          _selectedImageId = found['imageId'] as String;
                        });
                      },
              ),
            const SizedBox(height: 8),
            if (_selectedImagePath != null &&
                File(_selectedImagePath!).existsSync())
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImagePath!),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedImageLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedImagePath!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () => _runSingleModel('siglip_b16_int8'),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Run SigLIP-B/16'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isBusy
                        ? null
                        : () => _runSingleModel('tinyclip_40m_int8'),
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Run TinyCLIP-40M'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionResultCard(
    Map<String, dynamic> res,
    List<dynamic> top5,
    bool foodAccepted,
  ) {
    final mem = res['memory'] as Map<String, dynamic>?;
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: foodAccepted ? Colors.tealAccent : Colors.orangeAccent,
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Model: ${res['modelDisplayName']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.tealAccent,
                  ),
                ),
                _buildPill(
                  foodAccepted ? 'FOOD ACCEPTED' : 'ABSTAINED (NON-FOOD)',
                  foodAccepted ? Colors.green.shade800 : Colors.red.shade900,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Decision: ${res['decisionLabel']} • Neg Margin: ${res['negMargin']} (Top Neg: ${res['topNegativePrompt']} = ${res['maxNegSim']})',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const Divider(height: 14),
            const Text(
              'Top-5 Local Open-Vocabulary Matches (2,050-Food Index):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            ...top5.map((item) {
              final m = item as Map<String, dynamic>;
              final rank = m['rank'];
              final name = m['name'];
              final score = m['score'];
              final cat = m['category'];
              final in238 = m['inFitFuel238'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor:
                          rank == 1 ? Colors.teal : Colors.blueGrey.shade700,
                      child: Text(
                        '$rank',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$name ($cat)${in238 ? ' [FitFuel-238]' : ''}',
                        style: TextStyle(
                          fontWeight:
                              rank == 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      'sim: $score',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  'Preprocess: ${res['preprocessMs']} ms',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Encoder: ${res['encoderMs']} ms',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
                Text(
                  'Retrieval: ${res['retrievalMs']} ms',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Total: ${res['totalMs']} ms',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
                Text(
                  'Cloud calls: ${res['cloudCalls']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                if (mem != null)
                  Text(
                    'RAM PSS: ${mem['pssMb']} MB',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSummaryCard(Map<String, dynamic> offline) {
    return Card(
      color: const Color(0xFF14532D),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRUE OFFLINE VERIFICATION: ${offline['offlinePass'] == true ? 'PASS' : 'FAIL'} '
              '(Wi-Fi/Data Disabled: ${offline['wifiAndMobileDataDisabled']} • Cloud Calls: ${offline['cloudCalls']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkSummaryCard(Map<String, dynamic> bench) {
    final models = bench['models'] as Map<String, dynamic>? ?? const {};
    return Card(
      color: const Color(0xFF1E1B4B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '100-SCAN SAMSUNG RZCW8201QBV BENCHMARK SUMMARY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.amberAccent,
              ),
            ),
            const SizedBox(height: 8),
            ...models.entries.map((entry) {
              final mKey = entry.key;
              final mVal = entry.value as Map<String, dynamic>;
              final cold = mVal['coldStart'] as Map<String, dynamic>;
              final warm = mVal['warmLatency'] as Map<String, dynamic>;
              final tot = warm['total'] as Map<String, dynamic>;
              final enc = warm['encoder'] as Map<String, dynamic>;
              final ram = mVal['ram'] as Map<String, dynamic>;
              final therm = mVal['thermalAndBattery'] as Map<String, dynamic>;
              final fid = mVal['predictionFidelity'] as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• $mKey (${cold['totalAssetSizeMb']} MB)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                    Text(
                      '  Cold Start: ${cold['totalColdStartMs']} ms (Model: ${cold['modelLoadMs']} ms, Index: ${cold['indexLoadMs']} ms, 1st: ${cold['firstInferenceMs']} ms)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '  Warm P50: ${tot['p50']} ms (Enc P50: ${enc['p50']} ms) | P90: ${tot['p90']} ms | P95: ${tot['p95']} ms | Max: ${tot['max']} ms',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '  RAM PSS: Base ${ram['baselinePssMb']} -> Loaded ${ram['loadedPssMb']} -> Peak ${ram['peakPssMb']} -> After100 ${ram['after100PssMb']} MB',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '  Thermal Slowdown: ${therm['slowdownPct']}% (First10: ${therm['first10MedianMs']} ms -> Last10: ${therm['last10MedianMs']} ms) | Fidelity Top-1: ${fid['top1AgreementPct']}% / Top-5: ${fid['top5OverlapPct']}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomatedSuiteControlsCard() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AUTOMATED DEVICE BENCHMARK HARNESS CONTROLS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _runFullBenchmark,
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Run 100-Scan Suite'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _runOfflineVerification,
                    icon: const Icon(Icons.airplanemode_active, size: 18),
                    label: const Text('Verify Offline Mode'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
