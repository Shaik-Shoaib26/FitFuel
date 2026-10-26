import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food_scan/domain/entities/canonical_food_entry.dart';
import 'package:fitfuel/features/food_scan/domain/entities/nutrition_profile_tier.dart';
import 'package:fitfuel/features/food_scan/domain/services/open_vocabulary_food_recognizer.dart';

/// Metadata and content for an extensible food vocabulary pack.
class VocabularyPack {
  final String packId;
  final String version;
  final String? targetModelId;
  final List<CanonicalFoodEntry> entries;

  const VocabularyPack({
    required this.packId,
    required this.version,
    this.targetModelId = 'siglip_b16_int8',
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
        'packId': packId,
        'version': version,
        if (targetModelId != null) 'targetModelId': targetModelId,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory VocabularyPack.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return VocabularyPack(
      packId: json['packId'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      targetModelId: json['targetModelId'] as String? ?? 'siglip_b16_int8',
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map((e) => CanonicalFoodEntry.fromJson(e))
          .toList(),
    );
  }
}

/// Result of validating and applying a vocabulary pack.
class VocabularyPackValidationResult {
  final bool isValid;
  final String packId;
  final int totalEntries;
  final int visionEligibleEntries;
  final int textOnlyEntries;
  final List<String> validationErrors;
  final List<String> warnings;

  const VocabularyPackValidationResult({
    required this.isValid,
    required this.packId,
    required this.totalEntries,
    required this.visionEligibleEntries,
    required this.textOnlyEntries,
    this.validationErrors = const [],
    this.warnings = const [],
  });
}

/// Scalable, extensible global food vocabulary service (Phase 35.12 Sections 2 & 3).
///
/// Decouples food image concept taxonomy from hardcoded model classifiers.
/// Indexes 2,050+ canonical world food entries across major cuisines and regions,
/// supporting dynamic pack additions, alias lookup, and taxonomy queries.
class GlobalFoodVocabularyService {
  final Map<String, CanonicalFoodEntry> _entriesById = {};
  final Map<String, CanonicalFoodEntry> _entriesByNormalizedName = {};
  final Map<String, Set<String>> _aliasIndex = {};
  final Map<String, Set<String>> _cuisineIndex = {};
  final Map<String, Set<String>> _categoryIndex = {};
  final Set<String> _loadedPacks = {};
  final Set<String> _dynamicEntryIds = {};
  final Map<String, Set<String>> _packToEntryIds = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  int get count => _entriesById.length;
  int get totalEntries => _entriesById.length;
  Set<String> get loadedPacks => Set.unmodifiable(_loadedPacks);

  /// Returns all entries that possess a valid 768-d embedding for SigLIP image recognition.
  List<CanonicalFoodEntry> get imageEligibleEntries =>
      _entriesById.values.where((e) => e.hasImageSupport).toList();

  /// Returns entries that are text-search only (no valid 768-d vision embedding).
  List<CanonicalFoodEntry> get textOnlyEntries =>
      _entriesById.values.where((e) => !e.hasImageSupport).toList();

  /// Checks if a food entry supports on-device image matching.
  bool isImageEligible(String canonicalId) =>
      _entriesById[canonicalId]?.hasImageSupport ?? false;

  CanonicalFoodEntry? getEntry(String id) => getEntryById(id);

  List<CanonicalFoodEntry> filterByCuisine(String cuisine) {
    final norm = _normalize(cuisine);
    final ids = _cuisineIndex[norm] ?? const <String>{};
    return ids.map((id) => _entriesById[id]!).toList();
  }

  List<CanonicalFoodEntry> filterByCategory(String category) {
    final norm = _normalize(category);
    final ids = _categoryIndex[norm] ?? const <String>{};
    return ids.map((id) => _entriesById[id]!).toList();
  }

  static const String _kDynamicVocabStorageKey =
      'fitfuel_dynamic_vocabulary_packs_v1';

  /// Initializes the vocabulary service with the curated FitFuel catalog (238 items)
  /// and the comprehensive 2,050-concept open-vocabulary taxonomy.
  Future<void> initialize({
    AssetBundle? assetBundle,
    OpenVocabularyFoodRecognizer? recognizer,
    SharedPreferences? prefs,
  }) async {
    if (_isInitialized) return;

    // 1. Seed with FitFuel 238 predefined food items
    for (final food in PredefinedFoodData.foods) {
      final entry = CanonicalFoodEntry(
        canonicalId: food.id,
        preferredName: food.name,
        aliases: _generateDefaultAliases(food.id, food.name),
        category: food.category,
        cuisine: _inferCuisine(food.id, food.category),
        ingredients: food.ingredients ?? const [],
        source: 'FitFuel Curated 238',
        nutritionProfileIds: [food.id],
        nutritionTier: NutritionProfileTier.verifiedExact,
      );
      registerEntry(entry);
    }

    // 2. Seed curated world concepts across major cuisines
    _seedDefaultWorldConcepts();

    // 3. Load 2,050 concepts from bundled JSON asset if available
    try {
      final bundle = assetBundle ?? rootBundle;
      final jsonStr = await bundle.loadString('assets/ml/vocab_concepts_2050.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final concepts = data['concepts'] as List<dynamic>? ?? [];

      for (final item in concepts) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String? ?? '';
          if (id.isEmpty) continue;

          // If entry already registered from FitFuel 238, preserve verified status
          if (_entriesById.containsKey(id)) {
            continue;
          }

          final name = item['name'] as String? ?? id;
          final cat = item['cat'] as String? ?? item['category'] as String?;
          final parent = item['parent'] as String?;
          final inFitFuel238 = item['inFitFuel238'] == true;

          final entry = CanonicalFoodEntry(
            canonicalId: id,
            preferredName: name,
            aliases: _generateDefaultAliases(id, name),
            category: cat ?? parent ?? 'Food & Drink',
            cuisine: _inferCuisine(id, cat),
            source: 'Open Food Concepts 2050',
            nutritionProfileIds: inFitFuel238 ? [id] : const [],
            nutritionTier: inFitFuel238
                ? NutritionProfileTier.verifiedExact
                : NutritionProfileTier.unavailable,
          );
          registerEntry(entry);
        }
      }
    } catch (e) {
      debugPrint('[GlobalFoodVocabularyService] Note: Asset vocab_concepts_2050.json not loaded: $e');
    }

    // 4. Restore persisted dynamic vocabulary packs
    await _loadPersistedDynamicPacks(recognizer: recognizer, prefs: prefs);

    _isInitialized = true;
  }

  /// Registers or updates a canonical food entry in the vocabulary.
  void registerEntry(CanonicalFoodEntry entry) {
    _entriesById[entry.canonicalId] = entry;

    final normName = _normalize(entry.preferredName);
    if (normName.isNotEmpty) {
      _entriesByNormalizedName[normName] = entry;
    }

    for (final label in entry.allSearchableLabels) {
      final normLabel = _normalize(label);
      if (normLabel.isNotEmpty) {
        _aliasIndex.putIfAbsent(normLabel, () => <String>{}).add(entry.canonicalId);

        // Also index individual tokens for prefix/keyword search
        final tokens = normLabel.split(RegExp(r'\s+'));
        for (final token in tokens) {
          if (token.length >= 3) {
            _aliasIndex.putIfAbsent(token, () => <String>{}).add(entry.canonicalId);
          }
        }
      }
    }

    if (entry.cuisine != null && entry.cuisine!.isNotEmpty) {
      _cuisineIndex.putIfAbsent(_normalize(entry.cuisine!), () => <String>{}).add(entry.canonicalId);
    }

    if (entry.category != null && entry.category!.isNotEmpty) {
      _categoryIndex.putIfAbsent(_normalize(entry.category!), () => <String>{}).add(entry.canonicalId);
    }
  }

  /// Registers an external vocabulary pack dynamically (e.g. downloaded regional pack).
  ///
  /// Validates:
  /// - Embedding dimension matches active vision encoder (768 for SigLIP-B/16).
  /// - Embedding values are finite floats (no NaN or Inf).
  /// - Pack ID and version are present.
  ///
  /// Distinguishes vision-eligible entries from text-search-only entries.
  /// If validation fails or rollback occurs, existing vocabulary state is preserved.
  VocabularyPackValidationResult registerVocabularyPack(
    dynamic pack, {
    bool requireAllVisionEligible = false,
  }) {
    final VocabularyPack vocabPack;
    if (pack is VocabularyPack) {
      vocabPack = pack;
    } else if (pack is List<CanonicalFoodEntry>) {
      vocabPack = VocabularyPack(
        packId: 'unnamed_pack_${DateTime.now().millisecondsSinceEpoch}',
        version: '1.0.0',
        entries: pack,
      );
    } else {
      throw ArgumentError('pack must be VocabularyPack or List<CanonicalFoodEntry>');
    }

    return _applyValidatedPack(vocabPack, requireAllVisionEligible: requireAllVisionEligible);
  }

  VocabularyPackValidationResult _applyValidatedPack(
    VocabularyPack pack, {
    bool requireAllVisionEligible = false,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    int visionEligibleCount = 0;
    int textOnlyCount = 0;

    if (pack.packId.trim().isEmpty) {
      errors.add('Pack ID cannot be empty');
    }
    if (pack.version.trim().isEmpty) {
      errors.add('Pack version cannot be empty');
    }

    if (pack.targetModelId != null &&
        !pack.targetModelId!.toLowerCase().contains('siglip')) {
      final msg =
          'Incompatible model ID "${pack.targetModelId}". Expected SigLIP model compatible with siglip_b16_int8.';
      if (requireAllVisionEligible) {
        errors.add(msg);
      } else {
        warnings.add(
            'Pack target model "${pack.targetModelId}" may be incompatible with active SigLIP vision model');
      }
    }

    final validatedEntries = <CanonicalFoodEntry>[];
    final seenIdsInPack = <String>{};
    for (int i = 0; i < pack.entries.length; i++) {
      final entry = pack.entries[i];
      if (entry.canonicalId.trim().isEmpty) {
        errors.add('Entry at index $i has empty canonicalId');
        continue;
      }
      if (seenIdsInPack.contains(entry.canonicalId)) {
        errors.add('Duplicate canonicalId within pack: "${entry.canonicalId}"');
        continue;
      }
      seenIdsInPack.add(entry.canonicalId);

      final isFromThisPack =
          _packToEntryIds[pack.packId]?.contains(entry.canonicalId) ?? false;
      if (_entriesById.containsKey(entry.canonicalId) && !isFromThisPack) {
        errors.add(
            'Duplicate canonicalId "${entry.canonicalId}" already exists in registered vocabulary');
        continue;
      }

      if (entry.preferredName.trim().isEmpty) {
        errors.add('Entry "${entry.canonicalId}" has empty preferredName');
        continue;
      }

      if (entry.textEmbedding != null) {
        final emb = entry.textEmbedding!;
        if (emb.length != 768) {
          final msg = 'Entry "${entry.canonicalId}" embedding dimension is ${emb.length}, expected 768';
          if (requireAllVisionEligible) {
            errors.add(msg);
          } else {
            warnings.add('$msg - stripped vision support, registered for text search only');
          }
          validatedEntries.add(entry.copyWith(textEmbedding: null));
          textOnlyCount++;
          continue;
        }

        if (emb.any((v) => v.isNaN || v.isInfinite)) {
          final msg = 'Entry "${entry.canonicalId}" embedding contains NaN or Infinite values';
          if (requireAllVisionEligible) {
            errors.add(msg);
          } else {
            warnings.add('$msg - stripped vision support, registered for text search only');
          }
          validatedEntries.add(entry.copyWith(textEmbedding: null));
          textOnlyCount++;
          continue;
        }

        double normSq = 0.0;
        for (final v in emb) {
          normSq += v * v;
        }
        if (normSq < 1e-12) {
          final msg =
              'Entry "${entry.canonicalId}" embedding has zero or near-zero norm ($normSq)';
          if (requireAllVisionEligible) {
            errors.add(msg);
          } else {
            warnings.add(
                '$msg - stripped vision support, registered for text search only');
          }
          validatedEntries.add(entry.copyWith(textEmbedding: null));
          textOnlyCount++;
          continue;
        }

        visionEligibleCount++;
        validatedEntries.add(entry);
      } else {
        textOnlyCount++;
        if (requireAllVisionEligible) {
          errors.add('Entry "${entry.canonicalId}" lacks vision text embedding');
        } else {
          warnings.add('Entry "${entry.canonicalId}" has no embedding; text-search only');
        }
        validatedEntries.add(entry);
      }
    }

    if (errors.isNotEmpty) {
      // Validation failed: no mutations applied (rollback / intact state)
      return VocabularyPackValidationResult(
        isValid: false,
        packId: pack.packId,
        totalEntries: pack.entries.length,
        visionEligibleEntries: 0,
        textOnlyEntries: 0,
        validationErrors: errors,
        warnings: warnings,
      );
    }

    // Atomic snapshot before applying
    final backupEntriesById = Map<String, CanonicalFoodEntry>.from(_entriesById);
    final backupEntriesByName = Map<String, CanonicalFoodEntry>.from(_entriesByNormalizedName);
    final backupAliasIndex = _aliasIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupCuisineIndex = _cuisineIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupCategoryIndex = _categoryIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupPacks = Set<String>.from(_loadedPacks);
    final backupDynamicEntryIds = Set<String>.from(_dynamicEntryIds);
    final backupPackToEntryIds = _packToEntryIds.map((k, v) => MapEntry(k, Set<String>.from(v)));

    try {
      // If re-registering or updating existing pack, prune old entries removed from the pack
      if (_packToEntryIds.containsKey(pack.packId)) {
        final oldIds = _packToEntryIds[pack.packId]!;
        for (final oldId in oldIds) {
          if (!seenIdsInPack.contains(oldId)) {
            final oldEntry = _entriesById.remove(oldId);
            if (oldEntry != null) {
              _entriesByNormalizedName.remove(_normalize(oldEntry.preferredName));
              _dynamicEntryIds.remove(oldId);
            }
          }
        }
      }

      for (final entry in validatedEntries) {
        registerEntry(entry);
        _dynamicEntryIds.add(entry.canonicalId);
      }
      _loadedPacks.add(pack.packId);
      _packToEntryIds[pack.packId] =
          validatedEntries.map((e) => e.canonicalId).toSet();

      return VocabularyPackValidationResult(
        isValid: true,
        packId: pack.packId,
        totalEntries: validatedEntries.length,
        visionEligibleEntries: visionEligibleCount,
        textOnlyEntries: textOnlyCount,
        validationErrors: const [],
        warnings: warnings,
      );
    } catch (e) {
      // Rollback on any unexpected failure
      _entriesById.clear();
      _entriesById.addAll(backupEntriesById);
      _entriesByNormalizedName.clear();
      _entriesByNormalizedName.addAll(backupEntriesByName);
      _aliasIndex.clear();
      _aliasIndex.addAll(backupAliasIndex);
      _cuisineIndex.clear();
      _cuisineIndex.addAll(backupCuisineIndex);
      _categoryIndex.clear();
      _categoryIndex.addAll(backupCategoryIndex);
      _loadedPacks.clear();
      _loadedPacks.addAll(backupPacks);
      _dynamicEntryIds.clear();
      _dynamicEntryIds.addAll(backupDynamicEntryIds);
      _packToEntryIds.clear();
      _packToEntryIds.addAll(backupPackToEntryIds);

      return VocabularyPackValidationResult(
        isValid: false,
        packId: pack.packId,
        totalEntries: pack.entries.length,
        visionEligibleEntries: 0,
        textOnlyEntries: 0,
        validationErrors: ['Unexpected error during pack registration: $e (State rolled back)'],
        warnings: warnings,
      );
    }
  }

  /// Registers and synchronizes a vocabulary pack across both Dart and Native runtime.
  /// Enforces atomic rollback: if native synchronization fails, Dart mutations are rolled back.
  Future<VocabularyPackValidationResult> registerAndSyncVocabularyPack(
    dynamic pack, {
    OpenVocabularyFoodRecognizer? recognizer,
    bool requireAllVisionEligible = false,
    SharedPreferences? prefs,
  }) async {
    // 1. Take atomic snapshot of Dart state before validation
    final backupEntriesById = Map<String, CanonicalFoodEntry>.from(_entriesById);
    final backupEntriesByName = Map<String, CanonicalFoodEntry>.from(_entriesByNormalizedName);
    final backupAliasIndex = _aliasIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupCuisineIndex = _cuisineIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupCategoryIndex = _categoryIndex.map((k, v) => MapEntry(k, Set<String>.from(v)));
    final backupPacks = Set<String>.from(_loadedPacks);
    final backupDynamicEntryIds = Set<String>.from(_dynamicEntryIds);

    // 2. Validate and apply to Dart
    final localResult = registerVocabularyPack(
      pack,
      requireAllVisionEligible: requireAllVisionEligible,
    );

    if (!localResult.isValid) {
      return localResult;
    }

    final VocabularyPack vocabPack;
    if (pack is VocabularyPack) {
      vocabPack = pack;
    } else {
      vocabPack = VocabularyPack(
        packId: localResult.packId,
        version: '1.0.0',
        entries: pack as List<CanonicalFoodEntry>,
      );
    }

    // 3. If recognizer is supplied, capable, and available, sync with native retrieval matrix
    final rec = recognizer;
    if (rec != null && rec.isAvailable && rec is DynamicVocabularySyncCapable) {
      final sync = rec as DynamicVocabularySyncCapable;
      final nativeRes = await sync.registerDynamicVocabularyPack(
        vocabPack,
        requireAllVisionEligible: requireAllVisionEligible,
      );

      if (nativeRes == null || nativeRes['success'] != true) {
        // Atomic rollback of Dart state
        _entriesById.clear();
        _entriesById.addAll(backupEntriesById);
        _entriesByNormalizedName.clear();
        _entriesByNormalizedName.addAll(backupEntriesByName);
        _aliasIndex.clear();
        _aliasIndex.addAll(backupAliasIndex);
        _cuisineIndex.clear();
        _cuisineIndex.addAll(backupCuisineIndex);
        _categoryIndex.clear();
        _categoryIndex.addAll(backupCategoryIndex);
        _loadedPacks.clear();
        _loadedPacks.addAll(backupPacks);
        _dynamicEntryIds.clear();
        _dynamicEntryIds.addAll(backupDynamicEntryIds);

        final err = nativeRes?['error']?.toString() ?? 'Native registration failed';
        return VocabularyPackValidationResult(
          isValid: false,
          packId: vocabPack.packId,
          totalEntries: vocabPack.entries.length,
          visionEligibleEntries: 0,
          textOnlyEntries: 0,
          validationErrors: ['Native sync failed: $err (State rolled back)'],
          warnings: localResult.warnings,
        );
      }
    }

    // 4. Persist pack to SharedPreferences for app restart recovery
    await _persistDynamicPack(vocabPack, prefs: prefs);

    return localResult;
  }

  Future<void> _persistDynamicPack(
    VocabularyPack pack, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final existingJson = p.getString(_kDynamicVocabStorageKey);
      List<dynamic> list = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          list = json.decode(existingJson) as List<dynamic>? ?? [];
        } catch (_) {}
      }
      list.removeWhere((item) => item is Map && item['packId'] == pack.packId);
      list.add(pack.toJson());
      await p.setString(_kDynamicVocabStorageKey, json.encode(list));
    } catch (e) {
      debugPrint('[GlobalFoodVocabularyService] Failed to persist dynamic pack: $e');
    }
  }

  Future<void> _loadPersistedDynamicPacks({
    OpenVocabularyFoodRecognizer? recognizer,
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final existingJson = p.getString(_kDynamicVocabStorageKey);
      if (existingJson == null || existingJson.isEmpty) return;
      final list = json.decode(existingJson) as List<dynamic>? ?? [];
      for (final raw in list) {
        if (raw is Map<String, dynamic>) {
          try {
            final pack = VocabularyPack.fromJson(raw);
            _applyValidatedPack(pack, requireAllVisionEligible: false);
            final rec = recognizer;
            if (rec != null && rec.isAvailable && rec is DynamicVocabularySyncCapable) {
              final sync = rec as DynamicVocabularySyncCapable;
              final res = await sync.registerDynamicVocabularyPack(pack);
              if (res == null || res['success'] != true) {
                final err = res?['error'] ?? 'Native sync failed';
                debugPrint('[GlobalFoodVocabularyService] Native registration failed during startup reconciliation: $err');
                _unloadPack(pack.packId);
              }
            }
          } catch (e) {
            debugPrint('[GlobalFoodVocabularyService] Skipping corrupted dynamic pack: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[GlobalFoodVocabularyService] Failed to load persisted dynamic packs: $e');
    }
  }

  void _unloadPack(String packId) {
    final entryIds = _packToEntryIds.remove(packId) ?? {};
    for (final id in entryIds) {
      final entry = _entriesById.remove(id);
      if (entry != null) {
        _entriesByNormalizedName.remove(_normalize(entry.preferredName));
        _dynamicEntryIds.remove(id);
      }
    }
    _loadedPacks.remove(packId);
  }

  Future<void> clearDynamicVocabulary({
    OpenVocabularyFoodRecognizer? recognizer,
    SharedPreferences? prefs,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.remove(_kDynamicVocabStorageKey);
    } catch (_) {}

    final rec = recognizer;
    if (rec != null && rec.isAvailable && rec is DynamicVocabularySyncCapable) {
      final sync = rec as DynamicVocabularySyncCapable;
      await sync.clearDynamicVocabulary();
    }

    // Clean up dynamic entries from Dart
    for (final id in _dynamicEntryIds) {
      final entry = _entriesById.remove(id);
      if (entry != null) {
        _entriesByNormalizedName.remove(_normalize(entry.preferredName));
      }
    }
    final toRemove = _entriesById.values
        .where((e) => e.packVersion != null || e.embeddingModelId != null)
        .map((e) => e.canonicalId)
        .toList();
    for (final id in toRemove) {
      _entriesById.remove(id);
    }
    _dynamicEntryIds.clear();
    _loadedPacks.clear();
    _packToEntryIds.clear();
  }

  /// Diagnostically reconciles Dart, SharedPreferences, and Native concept states.
  /// Reports discrepancies between Dart memory, disk, and native concept counts.
  Future<Map<String, dynamic>> reconcileWithNative({
    OpenVocabularyFoodRecognizer? recognizer,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existingJson = p.getString(_kDynamicVocabStorageKey);
    final persistedPacks = <String>[];
    if (existingJson != null && existingJson.isNotEmpty) {
      try {
        final list = json.decode(existingJson) as List<dynamic>? ?? [];
        for (final item in list) {
          if (item is Map && item['packId'] != null) {
            persistedPacks.add(item['packId'].toString());
          }
        }
      } catch (_) {}
    }

    int? nativeBaseConcepts;
    int? nativeDynamicConcepts;
    int? nativeTotalConcepts;
    int? nativePacksCount;
    bool nativeAvailable = false;

    final rec = recognizer;
    if (rec != null && rec.isAvailable && rec is DynamicVocabularySyncCapable) {
      final sync = rec as DynamicVocabularySyncCapable;
      final info = await sync.getRegisteredVocabularyInfo();
      if (info != null) {
        nativeAvailable = true;
        nativeBaseConcepts = info['baseConcepts'] as int?;
        nativeDynamicConcepts = info['dynamicConcepts'] as int?;
        nativeTotalConcepts = info['totalConcepts'] as int?;
        nativePacksCount = info['dynamicPacksCount'] as int?;
      }
    }

    final missingFromNative = <String>[];
    if (nativeAvailable) {
      if ((nativePacksCount ?? 0) < _loadedPacks.length) {
        for (final packId in _loadedPacks) {
          missingFromNative.add(packId);
        }
      }
    }

    return {
      'dartLoadedPacks': _loadedPacks.toList(),
      'persistedPacks': persistedPacks,
      'dartTotalConcepts': totalEntries,
      'dartDynamicConcepts': _dynamicEntryIds.length,
      'nativeAvailable': nativeAvailable,
      'nativeBaseConcepts': nativeBaseConcepts,
      'nativeDynamicConcepts': nativeDynamicConcepts,
      'nativeTotalConcepts': nativeTotalConcepts,
      'nativePacksCount': nativePacksCount,
      'missingFromNative': missingFromNative,
      'isSynchronized': missingFromNative.isEmpty &&
          (!nativeAvailable || (nativePacksCount == _loadedPacks.length)),
    };
  }

  /// Resolves an entry by its exact canonical ID.
  CanonicalFoodEntry? getEntryById(String canonicalId) {
    return _entriesById[canonicalId];
  }

  /// Resolves an entry by exact or normalized preferred name.
  CanonicalFoodEntry? getEntryByName(String name) {
    final norm = _normalize(name);
    return _entriesByNormalizedName[norm];
  }

  /// Searches vocabulary by free-text query with optional cuisine and category filters.
  List<CanonicalFoodEntry> search(
    String query, {
    String? cuisineFilter,
    String? categoryFilter,
    int limit = 10,
  }) {
    final cleanQuery = _normalize(query);
    if (cleanQuery.isEmpty) return const [];

    final scoredMatches = <CanonicalFoodEntry, int>{};

    // 1. Direct ID match (highest priority: 1000)
    final byId = _entriesById[cleanQuery];
    if (byId != null) {
      scoredMatches[byId] = 1000;
    }

    // 2. Exact preferred name match (score: 800)
    final byName = _entriesByNormalizedName[cleanQuery];
    if (byName != null) {
      scoredMatches[byName] = (scoredMatches[byName] ?? 0) + 800;
    }

    // 3. Exact alias match (score: 500)
    final exactAliasIds = _aliasIndex[cleanQuery];
    if (exactAliasIds != null) {
      for (final id in exactAliasIds) {
        final entry = _entriesById[id];
        if (entry != null) {
          scoredMatches[entry] = (scoredMatches[entry] ?? 0) + 500;
        }
      }
    }

    // 4. Token & prefix matching
    final queryTokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    for (final token in queryTokens) {
      final tokenIds = _aliasIndex[token];
      if (tokenIds != null) {
        for (final id in tokenIds) {
          final entry = _entriesById[id];
          if (entry != null) {
            scoredMatches[entry] = (scoredMatches[entry] ?? 0) + 100;
          }
        }
      }
    }

    // Filter by cuisine and category if provided
    var results = scoredMatches.entries.where((e) {
      final entry = e.key;
      if (cuisineFilter != null && cuisineFilter.isNotEmpty) {
        if (_normalize(entry.cuisine ?? '') != _normalize(cuisineFilter)) {
          return false;
        }
      }
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        if (_normalize(entry.category ?? '') != _normalize(categoryFilter)) {
          return false;
        }
      }
      return true;
    }).toList();

    results.sort((a, b) => b.value.compareTo(a.value));
    return results.take(limit).map((e) => e.key).toList();
  }

  /// Returns all available cuisines in the indexed vocabulary.
  List<String> getAvailableCuisines() {
    final list = _entriesById.values
        .map((e) => e.cuisine)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  /// Returns all available categories in the indexed vocabulary.
  List<String> getAvailableCategories() {
    final list = _entriesById.values
        .map((e) => e.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  static List<String> _generateDefaultAliases(String id, String name) {
    final aliases = <String>{};
    final strippedId = id.replaceFirst('predefined_', '').replaceFirst('openvocab_', '').replaceAll('_', ' ');
    if (strippedId != name.toLowerCase()) {
      aliases.add(strippedId);
    }

    final lower = name.toLowerCase();
    if (lower.contains('(') && lower.contains(')')) {
      final insideParen = lower.substring(lower.indexOf('(') + 1, lower.indexOf(')')).trim();
      if (insideParen.isNotEmpty) aliases.add(insideParen);
      final outsideParen = lower.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      if (outsideParen.isNotEmpty) aliases.add(outsideParen);
    }

    // Common culinary synonym expansions
    if (lower.contains('roti')) aliases.add('chapati');
    if (lower.contains('chapati')) aliases.add('roti');
    if (lower.contains('curd')) aliases.addAll(['dahi', 'yogurt']);
    if (lower.contains('dahi')) aliases.addAll(['curd', 'yogurt']);
    if (lower.contains('rajma')) aliases.addAll(['kidney beans', 'rajma curry', 'rajma chawal']);
    if (lower.contains('samosa')) aliases.addAll(['sambusa', 'singara']);
    if (lower.contains('dosa')) aliases.addAll(['dosai', 'dhosa']);
    if (lower.contains('pasta')) aliases.addAll(['penne', 'spaghetti', 'macaroni']);
    if (lower.contains('pizza')) aliases.addAll(['flatbread', 'cheese pizza']);
    if (lower.contains('burger')) aliases.addAll(['hamburger', 'cheeseburger']);

    return aliases.toList();
  }

  static String? _inferCuisine(String id, String? category) {
    final idLower = id.toLowerCase();
    final catLower = (category ?? '').toLowerCase();

    if (idLower.contains('ind') ||
        idLower.contains('dal') ||
        idLower.contains('paneer') ||
        idLower.contains('tikka') ||
        idLower.contains('biryani') ||
        idLower.contains('dosa') ||
        idLower.contains('idli') ||
        idLower.contains('samosa') ||
        idLower.contains('rajma') ||
        idLower.contains('roti') ||
        idLower.contains('chapati') ||
        idLower.contains('chole')) {
      return 'Indian';
    }

    if (idLower.contains('pasta') ||
        idLower.contains('pizza') ||
        idLower.contains('spaghetti') ||
        idLower.contains('penne') ||
        idLower.contains('ravioli') ||
        idLower.contains('lasagna') ||
        idLower.contains('risotto')) {
      return 'Italian';
    }

    if (idLower.contains('taco') ||
        idLower.contains('burrito') ||
        idLower.contains('nacho') ||
        idLower.contains('guacamole') ||
        idLower.contains('salsa')) {
      return 'Mexican';
    }

    if (idLower.contains('sushi') ||
        idLower.contains('ramen') ||
        idLower.contains('udon') ||
        idLower.contains('tempura') ||
        idLower.contains('miso') ||
        idLower.contains('teriyaki')) {
      return 'East Asian';
    }

    if (idLower.contains('burger') ||
        idLower.contains('hot_dog') ||
        idLower.contains('pancake') ||
        idLower.contains('waffle') ||
        idLower.contains('bbq') ||
        idLower.contains('steak')) {
      return 'American';
    }

    if (idLower.contains('hummus') ||
        idLower.contains('falafel') ||
        idLower.contains('shawarma') ||
        idLower.contains('kebab') ||
        idLower.contains('baba_ganoush')) {
      return 'Middle Eastern';
    }

    if (catLower.contains('produce') ||
        catLower.contains('fruit') ||
        catLower.contains('vegetable')) {
      return 'Produce / Global';
    }

    return 'Global';
  }

  void _seedDefaultWorldConcepts() {
    final worldFoods = [
      const CanonicalFoodEntry(
        canonicalId: 'openvocab_samosa',
        preferredName: 'Samosa',
        aliases: ['singara', 'sambusa'],
        category: 'Snacks & Street Food',
        cuisine: 'Indian',
      ),
      const CanonicalFoodEntry(
        canonicalId: 'openvocab_margherita_pizza',
        preferredName: 'Pizza Margherita',
        aliases: ['margherita', 'cheese pizza'],
        category: 'Pizza & Italian',
        cuisine: 'Italian',
      ),
      const CanonicalFoodEntry(
        canonicalId: 'openvocab_shawarma',
        preferredName: 'Chicken Shawarma',
        aliases: ['shawarma wrap', 'doner'],
        category: 'Street Food & Sandwiches',
        cuisine: 'Middle Eastern',
      ),
      const CanonicalFoodEntry(
        canonicalId: 'openvocab_ramen',
        preferredName: 'Ramen',
        aliases: ['shoyu ramen', 'tonkotsu ramen'],
        category: 'Noodles & Soups',
        cuisine: 'Japanese',
      ),
      const CanonicalFoodEntry(
        canonicalId: 'openvocab_tacos_carnitas',
        preferredName: 'Pork Carnitas Tacos',
        aliases: ['carnitas', 'street tacos'],
        category: 'Mexican',
        cuisine: 'Mexican',
      ),
    ];
    for (final food in worldFoods) {
      registerEntry(food);
    }
  }
}
