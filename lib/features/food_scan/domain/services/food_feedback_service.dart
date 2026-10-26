import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Type of user feedback submitted for food recognition improvements.
enum FoodFeedbackType {
  /// User correcting a recognized candidate (e.g. model predicted Samosa, but it was Medu Vada).
  correction,

  /// User reporting an unsupported or unknown food not found in suggestions.
  unknownFood,

  /// User reporting inaccurate nutrition numbers for a matched food.
  incorrectNutrition,
}

/// A structured, privacy-preserving feedback record (Phase 35.12 Section 7).
class FoodFeedbackRecord {
  final String id;
  final DateTime timestamp;
  final String? scanSessionId;
  final String? predictedFoodName;
  final String correctedFoodName;
  final FoodFeedbackType feedbackType;
  final String? userNotes;
  final bool consentToUseImageForReview;

  const FoodFeedbackRecord({
    required this.id,
    required this.timestamp,
    this.scanSessionId,
    this.predictedFoodName,
    required this.correctedFoodName,
    required this.feedbackType,
    this.userNotes,
    this.consentToUseImageForReview = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        if (scanSessionId != null) 'scanSessionId': scanSessionId,
        if (predictedFoodName != null) 'predictedFoodName': predictedFoodName,
        'correctedFoodName': correctedFoodName,
        'feedbackType': feedbackType.name,
        if (userNotes != null) 'userNotes': userNotes,
        'consentToUseImageForReview': consentToUseImageForReview,
      };

  factory FoodFeedbackRecord.fromJson(Map<String, dynamic> json) {
    return FoodFeedbackRecord(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      scanSessionId: json['scanSessionId'] as String?,
      predictedFoodName: json['predictedFoodName'] as String?,
      correctedFoodName: json['correctedFoodName'] as String? ?? '',
      feedbackType: FoodFeedbackType.values.firstWhere(
        (t) => t.name == json['feedbackType'],
        orElse: () => FoodFeedbackType.correction,
      ),
      userNotes: json['userNotes'] as String?,
      consentToUseImageForReview: json['consentToUseImageForReview'] == true,
    );
  }
}

/// Service managing user feedback, corrections, and new food reports (Phase 35.12 Section 7).
///
/// Follows strict privacy guidelines:
/// - Never automatically treats user corrections as verified nutrition facts.
/// - Never uploads private food photos for training without explicit user consent.
/// - Stores feedback locally in a reviewable queue for curation.
/// - Persists across app launches via SharedPreferences with deduplication.
class FoodFeedbackService {
  static const String storageKey = 'fitfuel_food_feedback_queue_v1';

  SharedPreferences? _prefs;
  final List<FoodFeedbackRecord> _feedbackQueue = [];
  bool _isInitialized = false;

  FoodFeedbackService([SharedPreferences? prefs]) : _prefs = prefs;

  List<FoodFeedbackRecord> get pendingFeedback => List.unmodifiable(_feedbackQueue);
  int get pendingCount => _feedbackQueue.length;
  bool get isInitialized => _isInitialized;

  /// Initializes the service and loads persisted records from SharedPreferences.
  Future<void> initialize({SharedPreferences? prefs}) async {
    if (prefs != null) {
      _prefs = prefs;
    }
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('[FoodFeedbackService] SharedPreferences unavailable: $e');
      }
    }
    await _loadFromStorage();
    _isInitialized = true;
  }

  Future<void> _loadFromStorage() async {
    if (_prefs == null) return;
    try {
      final jsonStr = _prefs!.getString(storageKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) return;
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        _feedbackQueue.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              _feedbackQueue.add(FoodFeedbackRecord.fromJson(item));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[FoodFeedbackService] Ignored corrupted feedback storage: $e');
    }
  }

  Future<void> _saveToStorage() async {
    if (_prefs == null) return;
    try {
      final list = _feedbackQueue.map((r) => r.toJson()).toList();
      await _prefs!.setString(storageKey, json.encode(list));
    } catch (e) {
      debugPrint('[FoodFeedbackService] Failed to persist feedback: $e');
    }
  }

  /// Checks if a feedback record for this scanSessionId and corrected food name already exists.
  bool isDuplicate(String? scanSessionId, String correctedFoodName) {
    if (scanSessionId == null || scanSessionId.trim().isEmpty) return false;
    final normName = correctedFoodName.trim().toLowerCase();
    return _feedbackQueue.any((r) =>
        r.scanSessionId == scanSessionId &&
        r.correctedFoodName.trim().toLowerCase() == normName);
  }

  /// Records a user-submitted food recognition correction or unknown food report.
  /// Deduplicates: if matching feedback already exists for this scanSessionId and food,
  /// returns the existing record without appending a duplicate.
  Future<FoodFeedbackRecord> submitFeedback({
    required String correctedFoodName,
    required FoodFeedbackType feedbackType,
    String? predictedFoodName,
    String? scanSessionId,
    String? userNotes,
    bool consentToUseImageForReview = false,
  }) async {
    if (!_isInitialized && _prefs == null) {
      await initialize();
    }

    final trimmedName = correctedFoodName.trim();

    // Deduplication check
    if (scanSessionId != null && scanSessionId.trim().isNotEmpty) {
      final normName = trimmedName.toLowerCase();
      final existingIndex = _feedbackQueue.indexWhere((r) =>
          r.scanSessionId == scanSessionId &&
          r.correctedFoodName.trim().toLowerCase() == normName);

      if (existingIndex >= 0) {
        final existing = _feedbackQueue[existingIndex];
        if (kDebugMode) {
          debugPrint(
            '[FoodFeedbackService] Deduplicated feedback id=${existing.id} for session=$scanSessionId food="$trimmedName"',
          );
        }
        return existing;
      }
    }

    final record = FoodFeedbackRecord(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}_${_feedbackQueue.length}',
      timestamp: DateTime.now(),
      scanSessionId: scanSessionId,
      predictedFoodName: predictedFoodName,
      correctedFoodName: trimmedName,
      feedbackType: feedbackType,
      userNotes: userNotes?.trim(),
      consentToUseImageForReview: consentToUseImageForReview,
    );

    _feedbackQueue.add(record);
    await _saveToStorage();

    if (kDebugMode) {
      debugPrint(
        '[FoodFeedbackService] recorded feedback id=${record.id} '
        'type=${record.feedbackType.name} '
        'corrected="${record.correctedFoodName}" '
        'consentImage=$consentToUseImageForReview',
      );
    }

    return record;
  }

  /// Returns feedback filtered by type.
  List<FoodFeedbackRecord> getFeedbackByType(FoodFeedbackType type) {
    return _feedbackQueue.where((r) => r.feedbackType == type).toList();
  }

  /// Exports current feedback queue as structured JSON string.
  String exportQueueAsJson({bool pretty = false}) {
    final list = _feedbackQueue.map((r) => r.toJson()).toList();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(list)
        : json.encode(list);
  }

  /// Clears pending feedback queue after export or synchronization.
  Future<void> clearQueue() async {
    _feedbackQueue.clear();
    await _saveToStorage();
  }

  /// Removes an individual feedback record by ID.
  Future<bool> removeFeedback(String id) async {
    final index = _feedbackQueue.indexWhere((r) => r.id == id);
    if (index >= 0) {
      _feedbackQueue.removeAt(index);
      await _saveToStorage();
      return true;
    }
    return false;
  }
}
