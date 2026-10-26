import 'package:fitfuel/features/food/data/datasources/predefined_food_data.dart';
import 'package:fitfuel/features/food/domain/entities/food_entity.dart';
import 'package:fitfuel/features/food/domain/utils/food_search_engine.dart';
import 'package:fitfuel/features/food_scan/domain/entities/open_vocabulary_food_candidate.dart';

/// Resolves user-confirmed Tier-2 open-vocabulary food candidates (`SigLIP-B/16`)
/// against FitFuel's trusted nutrition catalog using STRICT exact/verified
/// canonical mappings only.
///
/// Safety rules (Phase 35.11B Sections 20–26, 62–66):
/// - Never invents or fabricates calories/macros.
/// - Never silently substitutes culinary siblings (e.g., never maps
///   `Creamy Penne Pasta` or `Penne Alfredo` to generic `Standard Pasta (Cooked)`
///   automatically, never maps `Tsukemen` to `Ramen`, never maps `Flammkuchen` to `Pizza`).
/// - Deduplicates candidate lists so Top-3 suggestions always contain distinct
///   canonical food concepts.
class TrustedOpenVocabNutritionMapper {
  TrustedOpenVocabNutritionMapper._();

  /// Cached O(1) lookup of FitFuel's 238 predefined foods by canonical ID.
  static final Map<String, FoodEntity> _defaultCatalogById = {
    for (final model in PredefinedFoodData.foods) model.id: model.toEntity(),
  };

  /// Cached O(1) lookup of FitFuel's 238 predefined foods by normalized exact name.
  static final Map<String, FoodEntity> _defaultCatalogByNormalizedName = {
    for (final model in PredefinedFoodData.foods)
      _normalizeExactName(model.name): model.toEntity(),
  };

  /// Explicit verified 1:1 synonym mappings where an open-vocabulary concept ID
  /// refers to the exact same food item as a FitFuel predefined catalog entry.
  ///
  /// Culinary siblings with materially different preparation/sauces (such as
  /// `openvocab_creamy_penne_pasta`, `openvocab_penne_alfredo`, `predefined_pasta`,
  /// `predefined_burger`, `predefined_pizza`, `openvocab_tsukemen`, `openvocab_flammkuchen`)
  /// are intentionally EXCLUDED and require explicit user selection in Search Foods.
  static const Map<String, String> kVerifiedOpenVocabToFitFuelCatalogIds = {
    'openvocab_hummus': 'predefined_classic_hummus',
    'open_vocab_hummus': 'predefined_classic_hummus',
    'openvocab_pesarattu': 'predefined_pesarattu',
    'open_vocab_pesarattu': 'predefined_pesarattu',
    'openvocab_cantaloupe': 'predefined_muskmelon',
    'open_vocab_cantaloupe': 'predefined_muskmelon',
    'openvocab_bitter_gourd': 'predefined_bitter_gourd',
    'open_vocab_bitter_gourd': 'predefined_bitter_gourd',
    'openvocab_ridge_gourd': 'predefined_ridge_gourd',
    'open_vocab_ridge_gourd': 'predefined_ridge_gourd',
    'openvocab_tempeh': 'predefined_tempeh',
    'open_vocab_tempeh': 'predefined_tempeh',
    'openvocab_espresso': 'predefined_black_coffee',
    'open_vocab_espresso': 'predefined_black_coffee',
    'openvocab_beef_sirloin': 'predefined_beef_steak',
    'open_vocab_beef_sirloin': 'predefined_beef_steak',
    'openvocab_white_rice': 'predefined_steamed_rice',
    'open_vocab_white_rice': 'predefined_steamed_rice',
    'openvocab_plain_rice': 'predefined_steamed_rice',
    'open_vocab_plain_rice': 'predefined_steamed_rice',
    'openvocab_steamed_rice': 'predefined_steamed_rice',
    'open_vocab_steamed_rice': 'predefined_steamed_rice',
    'openvocab_samosa': 'predefined_samosa',
    'open_vocab_samosa': 'predefined_samosa',
    'openvocab_idli': 'predefined_idli',
    'open_vocab_idli': 'predefined_idli',
    'openvocab_plain_dosa': 'predefined_dosa',
    'open_vocab_plain_dosa': 'predefined_dosa',
    'openvocab_masala_dosa': 'predefined_masala_dosa',
    'open_vocab_masala_dosa': 'predefined_masala_dosa',
    'openvocab_chapati': 'predefined_chapati',
    'open_vocab_chapati': 'predefined_chapati',
    'openvocab_tandoori_roti': 'predefined_roti',
    'open_vocab_tandoori_roti': 'predefined_roti',
    'openvocab_boiled_egg': 'predefined_hard_boiled_eggs',
    'open_vocab_boiled_egg': 'predefined_hard_boiled_eggs',
    'openvocab_hard_boiled_egg': 'predefined_hard_boiled_eggs',
    'open_vocab_hard_boiled_egg': 'predefined_hard_boiled_eggs',
    'openvocab_scrambled_eggs': 'predefined_scrambled_eggs',
    'open_vocab_scrambled_eggs': 'predefined_scrambled_eggs',
    'openvocab_omelette': 'predefined_egg_omelette',
    'open_vocab_omelette': 'predefined_egg_omelette',
    'openvocab_dal_tadka': 'predefined_dal_tadka',
    'open_vocab_dal_tadka': 'predefined_dal_tadka',
    'openvocab_apple': 'predefined_apple',
    'open_vocab_apple': 'predefined_apple',
    'openvocab_banana': 'predefined_banana',
    'open_vocab_banana': 'predefined_banana',
    'openvocab_whole_wheat_bread': 'predefined_whole_wheat_bread',
    'open_vocab_whole_wheat_bread': 'predefined_whole_wheat_bread',
    'openvocab_rajma_chawal': 'predefined_rajma_chawal',
    'open_vocab_rajma_chawal': 'predefined_rajma_chawal',
    'openvocab_burger': 'predefined_burger',
    'open_vocab_burger': 'predefined_burger',
    'openvocab_cheeseburger': 'predefined_cheeseburger',
    'open_vocab_cheeseburger': 'predefined_cheeseburger',
    'openvocab_sambar': 'predefined_sambar',
    'open_vocab_sambar': 'predefined_sambar',
    'openvocab_rasam': 'predefined_rasam',
    'open_vocab_rasam': 'predefined_rasam',
    'openvocab_poha': 'predefined_poha',
    'open_vocab_poha': 'predefined_poha',
    'openvocab_curd': 'predefined_curd',
    'open_vocab_curd': 'predefined_curd',
    'openvocab_dahi': 'predefined_curd',
    'open_vocab_dahi': 'predefined_curd',
    'openvocab_chicken_curry': 'predefined_chicken_curry',
    'open_vocab_chicken_curry': 'predefined_chicken_curry',
    'openvocab_fish_curry': 'predefined_fish_curry',
    'open_vocab_fish_curry': 'predefined_fish_curry',
    'openvocab_butter_chicken': 'predefined_butter_chicken',
    'open_vocab_butter_chicken': 'predefined_butter_chicken',
    'openvocab_paneer_bhurji': 'predefined_paneer_bhurji',
    'open_vocab_paneer_bhurji': 'predefined_paneer_bhurji',
    'openvocab_chicken_biryani': 'predefined_chicken_biryani',
    'open_vocab_chicken_biryani': 'predefined_chicken_biryani',
    'openvocab_veg_biryani': 'predefined_veg_biryani',
    'open_vocab_veg_biryani': 'predefined_veg_biryani',
    'openvocab_palak_paneer': 'predefined_palak_paneer',
    'open_vocab_palak_paneer': 'predefined_palak_paneer',
    'openvocab_dal_fry': 'predefined_dal_fry',
    'open_vocab_dal_fry': 'predefined_dal_fry',
    'openvocab_salad': 'predefined_mixed_veg_salad',
    'open_vocab_salad': 'predefined_mixed_veg_salad',
    'openvocab_green_salad': 'predefined_mixed_veg_salad',
    'open_vocab_green_salad': 'predefined_mixed_veg_salad',
    'openvocab_pulao': 'predefined_veg_pulao',
    'open_vocab_pulao': 'predefined_veg_pulao',

    // Phase 35.13.3: Rich Indian Curries, Dals, Flatbreads, Salads & Specialties
    'openvocab_nihari': 'predefined_mutton_curry',
    'open_vocab_nihari': 'predefined_mutton_curry',
    'predefined_paneer_butter_masala': 'predefined_palak_paneer',
    'openvocab_paneer_butter_masala': 'predefined_palak_paneer',
    'open_vocab_paneer_butter_masala': 'predefined_palak_paneer',
    'predefined_dal_makhani': 'predefined_dal_tadka',
    'openvocab_dal_makhani': 'predefined_dal_tadka',
    'open_vocab_dal_makhani': 'predefined_dal_tadka',
    'predefined_pav_bhaji': 'predefined_mixed_veg_curry',
    'openvocab_pav_bhaji': 'predefined_mixed_veg_curry',
    'open_vocab_pav_bhaji': 'predefined_mixed_veg_curry',
    'openvocab_butter_naan': 'predefined_roti',
    'open_vocab_butter_naan': 'predefined_roti',
    'openvocab_garlic_naan': 'predefined_roti',
    'open_vocab_garlic_naan': 'predefined_roti',
    'openvocab_naan': 'predefined_roti',
    'open_vocab_naan': 'predefined_roti',
    'openvocab_akki_roti': 'predefined_roti',
    'open_vocab_akki_roti': 'predefined_roti',
    'openvocab_malai_kofta': 'predefined_mixed_veg_curry',
    'open_vocab_malai_kofta': 'predefined_mixed_veg_curry',
    'openvocab_navratan_korma': 'predefined_mixed_veg_curry',
    'open_vocab_navratan_korma': 'predefined_mixed_veg_curry',
    'openvocab_gatte_ki_sabzi': 'predefined_mixed_veg_curry',
    'open_vocab_gatte_ki_sabzi': 'predefined_mixed_veg_curry',
    'openvocab_panchmel_dal': 'predefined_dal_tadka',
    'open_vocab_panchmel_dal': 'predefined_dal_tadka',
    'openvocab_cholar_dal': 'predefined_chana_dal',
    'open_vocab_cholar_dal': 'predefined_chana_dal',
    'openvocab_dal_pakwan': 'predefined_chana_dal',
    'open_vocab_dal_pakwan': 'predefined_chana_dal',
    'openvocab_dal_dhokli': 'predefined_toor_dal',
    'open_vocab_dal_dhokli': 'predefined_toor_dal',
    'openvocab_odia_dalma': 'predefined_toor_dal',
    'open_vocab_odia_dalma': 'predefined_toor_dal',
    'openvocab_dal_baati_churma': 'predefined_dal_tadka',
    'open_vocab_dal_baati_churma': 'predefined_dal_tadka',
    'openvocab_soya_chaap_masala': 'predefined_mixed_veg_curry',
    'open_vocab_soya_chaap_masala': 'predefined_mixed_veg_curry',
    'openvocab_kaju_curry': 'predefined_mixed_veg_curry',
    'open_vocab_kaju_curry': 'predefined_mixed_veg_curry',
    'openvocab_kofta_curry': 'predefined_mixed_veg_curry',
    'open_vocab_kofta_curry': 'predefined_mixed_veg_curry',
    'openvocab_kashmiri_pulao': 'predefined_veg_pulao',
    'open_vocab_kashmiri_pulao': 'predefined_veg_pulao',
    'openvocab_chingri_malai_curry': 'predefined_prawn_masala',
    'open_vocab_chingri_malai_curry': 'predefined_prawn_masala',
    'openvocab_crab_masala': 'predefined_fish_curry',
    'open_vocab_crab_masala': 'predefined_fish_curry',
    'openvocab_dhokar_dalna': 'predefined_chana_dal',
    'open_vocab_dhokar_dalna': 'predefined_chana_dal',
    'openvocab_greek_salad': 'predefined_mixed_veg_salad',
    'open_vocab_greek_salad': 'predefined_mixed_veg_salad',
    'openvocab_caprese_salad': 'predefined_mixed_veg_salad',
    'open_vocab_caprese_salad': 'predefined_mixed_veg_salad',
    'openvocab_tabbouleh_salad': 'predefined_mixed_veg_salad',
    'open_vocab_tabbouleh_salad': 'predefined_mixed_veg_salad',
    'openvocab_som_tum_papaya_salad': 'predefined_mixed_veg_salad',
    'open_vocab_som_tum_papaya_salad': 'predefined_mixed_veg_salad',
  };

  /// Verified 1:1 normalized name aliases that map to an exact FitFuel catalog ID.
  static const Map<String, String> kVerifiedNormalizedNameAliases = {
    // Rice
    'white rice': 'predefined_steamed_rice',
    'plain rice': 'predefined_steamed_rice',
    'steamed rice': 'predefined_steamed_rice',
    'cooked rice': 'predefined_steamed_rice',
    'chawal': 'predefined_steamed_rice',
    'boiled rice': 'predefined_steamed_rice',
    'basmati rice': 'predefined_steamed_rice',
    'steamed basmati rice': 'predefined_steamed_rice',
    'brown rice': 'predefined_brown_rice_ind',
    'cooked brown rice': 'predefined_brown_rice_ind',
    'jeera rice': 'predefined_jeera_rice',
    'cumin rice': 'predefined_jeera_rice',

    // Dosa & Idli
    'plain dosa': 'predefined_dosa',
    'sada dosa': 'predefined_dosa',
    'masala dosa': 'predefined_masala_dosa',
    'masala dosas': 'predefined_masala_dosa',
    'crispy masala dosa': 'predefined_masala_dosa',
    'rava dosa': 'predefined_rava_dosa',
    'idli': 'predefined_idli',
    'idlis': 'predefined_idli',
    'idly': 'predefined_idli',
    'idlys': 'predefined_idli',
    'steamed idli': 'predefined_idli',
    'steamed idlis': 'predefined_idli',

    // Roti & Chapati
    'chapati': 'predefined_chapati',
    'chapatis': 'predefined_chapati',
    'chapatti': 'predefined_chapati',
    'chapattis': 'predefined_chapati',
    'phulka': 'predefined_chapati',
    'fulka': 'predefined_chapati',
    'tandoori roti': 'predefined_roti',

    // Dal
    'dal tadka': 'predefined_dal_tadka',
    'tadka dal': 'predefined_dal_tadka',
    'yellow moong dal': 'predefined_moong_dal',
    'toor dal': 'predefined_toor_dal',
    'arhar dal': 'predefined_toor_dal',
    'chana dal': 'predefined_chana_dal',

    // Eggs
    'boiled egg': 'predefined_hard_boiled_eggs',
    'boiled eggs': 'predefined_hard_boiled_eggs',
    'hard boiled egg': 'predefined_hard_boiled_eggs',
    'hard-boiled egg': 'predefined_hard_boiled_eggs',
    'hard boiled eggs': 'predefined_hard_boiled_eggs',
    'scrambled egg': 'predefined_scrambled_eggs',
    'scrambled eggs': 'predefined_scrambled_eggs',
    'egg omelette': 'predefined_egg_omelette',
    'omelette': 'predefined_egg_omelette',
    'omelet': 'predefined_egg_omelette',
    'egg bhurji': 'predefined_egg_bhurji',
    'anda bhurji': 'predefined_egg_bhurji',

    // Bread
    'whole wheat bread': 'predefined_whole_wheat_bread',
    'wheat bread': 'predefined_whole_wheat_bread',
    'brown bread': 'predefined_whole_wheat_bread',
    'multigrain bread': 'predefined_multigrain_bread',

    // Samosa
    'samosa': 'predefined_samosa',
    'samosas': 'predefined_samosa',
    'punjabi samosa': 'predefined_samosa',
    'vegetable samosa': 'predefined_samosa',

    // Salads & Fruits
    'mixed green salad': 'predefined_mixed_veg_salad',
    'green salad': 'predefined_mixed_veg_salad',
    'garden salad': 'predefined_mixed_veg_salad',
    'vegetable salad': 'predefined_mixed_veg_salad',
    'caesar salad': 'predefined_caesar_salad',
    'apple': 'predefined_apple',
    'apples': 'predefined_apple',
    'red apple': 'predefined_apple',
    'banana': 'predefined_banana',
    'bananas': 'predefined_banana',
    'ripe banana': 'predefined_banana',

    // Curries & Combos
    'rajma chawal': 'predefined_rajma_chawal',
    'kadhi chawal': 'predefined_kadhi_chawal',
    'palak paneer': 'predefined_palak_paneer',
    'aloo gobi': 'predefined_aloo_gobi',
    'bhindi masala': 'predefined_bhindi_masala',
    'sambar': 'predefined_sambar',
    'rasam': 'predefined_rasam',
    'poha': 'predefined_poha',
    'kanda poha': 'predefined_poha',
    'curd': 'predefined_curd',
    'dahi': 'predefined_curd',
    'indian curd': 'predefined_curd',
    'plain curd': 'predefined_curd',
    'chicken curry': 'predefined_chicken_curry',
    'fish curry': 'predefined_fish_curry',
    'butter chicken': 'predefined_butter_chicken',
    'paneer bhurji': 'predefined_paneer_bhurji',
    'chicken biryani': 'predefined_chicken_biryani',
    'veg biryani': 'predefined_veg_biryani',
    'vegetable biryani': 'predefined_veg_biryani',
    'dal fry': 'predefined_dal_fry',
    'salad': 'predefined_mixed_veg_salad',
    'salad bowl': 'predefined_mixed_veg_salad',
    'kachumber': 'predefined_mixed_veg_salad',
    'kachumber salad': 'predefined_mixed_veg_salad',
    'pulao': 'predefined_veg_pulao',
    'veg pulao': 'predefined_veg_pulao',

    // Phase 35.13.3: Rich Regional Curries, Dals, Flatbreads, Salads & Specialties
    'nihari': 'predefined_mutton_curry',
    'mutton nihari': 'predefined_mutton_curry',
    'beef nihari': 'predefined_mutton_curry',
    'paneer butter masala': 'predefined_palak_paneer',
    'paneer makhani': 'predefined_palak_paneer',
    'shahi paneer': 'predefined_palak_paneer',
    'dal makhani': 'predefined_dal_tadka',
    'makhani dal': 'predefined_dal_tadka',
    'pav bhaji': 'predefined_mixed_veg_curry',
    'pani puri': 'predefined_samosa',
    'golgappa': 'predefined_samosa',
    'puchka': 'predefined_samosa',
    'naan': 'predefined_roti',
    'butter naan': 'predefined_roti',
    'garlic naan': 'predefined_roti',
    'tandoori naan': 'predefined_roti',
    'akki roti': 'predefined_roti',
    'malai kofta': 'predefined_mixed_veg_curry',
    'navratan korma': 'predefined_mixed_veg_curry',
    'gatte ki sabzi': 'predefined_mixed_veg_curry',
    'panchmel dal': 'predefined_dal_tadka',
    'cholar dal': 'predefined_chana_dal',
    'dal pakwan': 'predefined_chana_dal',
    'dal dhokli': 'predefined_toor_dal',
    'odia dalma': 'predefined_toor_dal',
    'dal baati churma': 'predefined_dal_tadka',
    'soya chaap': 'predefined_mixed_veg_curry',
    'soya chaap masala': 'predefined_mixed_veg_curry',
    'kaju curry': 'predefined_mixed_veg_curry',
    'kofta curry': 'predefined_mixed_veg_curry',
    'kashmiri pulao': 'predefined_veg_pulao',
    'chingri malai curry': 'predefined_prawn_masala',
    'crab masala': 'predefined_fish_curry',
    'dhokar dalna': 'predefined_chana_dal',
    'greek salad': 'predefined_mixed_veg_salad',
    'caprese salad': 'predefined_mixed_veg_salad',
    'tabbouleh salad': 'predefined_mixed_veg_salad',
    'tabbouleh': 'predefined_mixed_veg_salad',
    'som tum': 'predefined_mixed_veg_salad',
    'som tum papaya salad': 'predefined_mixed_veg_salad',
  };

  /// Known alias phrases that collapse to the same canonical concept key when
  /// deduplicating Top-K open-vocabulary suggestions (Section 15).
  static const Map<String, String> _kAliasDuplicateCollapseMap = {
    'penne': 'penne pasta',
    'penne noodle': 'penne pasta',
    'penne noodles': 'penne pasta',
    'penne noodle dish': 'penne pasta',
    'plate of penne pasta': 'penne pasta',
    'bowl of penne pasta': 'penne pasta',
    'fresh penne pasta': 'penne pasta',
    'creamy penne': 'creamy penne pasta',
    'bowl of creamy penne pasta': 'creamy penne pasta',
    'plate of creamy penne pasta': 'creamy penne pasta',
    'alfredo penne': 'penne alfredo',
    'penne fettuccine alfredo': 'penne alfredo',
    'classic chickpea hummus': 'hummus',
    'chickpea hummus': 'hummus',
    'indian samosa': 'samosa',
    'vegetable samosa': 'samosa',
    'fried samosa': 'samosa',
    'crispy masala dosa': 'masala dosa',
    'south indian masala dosa': 'masala dosa',
  };

  /// Resolves an [OpenVocabularyFoodCandidate] to a trusted [FoodEntity] ONLY if
  /// an exact or verified 1:1 FitFuel catalog entry exists.
  /// Returns `null` if no exact match exists (e.g., `Creamy Penne Pasta`, `Burger`).
  static FoodEntity? resolveTrustedCatalogFood(
    OpenVocabularyFoodCandidate candidate, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    return resolveByIdOrExactName(
      canonicalFoodId: candidate.canonicalFoodId,
      canonicalName: candidate.canonicalName,
      explicitFitFuelFoodId: candidate.fitFuelFoodId,
      foodCatalog: foodCatalog,
    );
  }

  /// True when [candidate] has an explicit verified 1:1 alias mapping to a FitFuel catalog entry.
  static bool hasVerifiedAlias(OpenVocabularyFoodCandidate candidate) {
    final targetById =
        kVerifiedOpenVocabToFitFuelCatalogIds[candidate.canonicalFoodId];
    if (targetById != null && _defaultCatalogById.containsKey(targetById)) {
      return true;
    }
    final normName = _normalizeExactName(candidate.canonicalName);
    final targetByName = kVerifiedNormalizedNameAliases[normName];
    return targetByName != null && _defaultCatalogById.containsKey(targetByName);
  }

  /// True when [candidate] directly matches a FitFuel catalog item by ID or exact normalized name.
  static bool isExactCatalogFood(
    OpenVocabularyFoodCandidate candidate, {
    List<FoodEntity> foodCatalog = const [],
  }) {
    final resolved = resolveTrustedCatalogFood(
      candidate,
      foodCatalog: foodCatalog,
    );
    return resolved != null && !hasVerifiedAlias(candidate);
  }

  /// Resolves by [canonicalFoodId], [explicitFitFuelFoodId], or 100% exact
  /// normalized name match in [foodCatalog] / [PredefinedFoodData.foods].
  static FoodEntity? resolveByIdOrExactName({
    required String canonicalFoodId,
    required String canonicalName,
    String? explicitFitFuelFoodId,
    List<FoodEntity> foodCatalog = const [],
  }) {
    final Map<String, FoodEntity> catalogById;
    final Map<String, FoodEntity> catalogByName;

    if (foodCatalog.isNotEmpty) {
      catalogById = {
        ..._defaultCatalogById,
        for (final f in foodCatalog) f.id: f,
      };
      catalogByName = {
        ..._defaultCatalogByNormalizedName,
        for (final f in foodCatalog) _normalizeExactName(f.name): f,
      };
    } else {
      catalogById = _defaultCatalogById;
      catalogByName = _defaultCatalogByNormalizedName;
    }

    // 1. Direct canonicalFoodId match in FitFuel 238 catalog
    if (canonicalFoodId.isNotEmpty &&
        catalogById.containsKey(canonicalFoodId)) {
      return catalogById[canonicalFoodId];
    }

    // 2. Explicit fitFuelFoodId match
    if (explicitFitFuelFoodId != null &&
        explicitFitFuelFoodId.isNotEmpty &&
        catalogById.containsKey(explicitFitFuelFoodId)) {
      return catalogById[explicitFitFuelFoodId];
    }

    // 3. Verified 1:1 synonym map by ID
    final verifiedTargetId =
        kVerifiedOpenVocabToFitFuelCatalogIds[canonicalFoodId];
    if (verifiedTargetId != null && catalogById.containsKey(verifiedTargetId)) {
      return catalogById[verifiedTargetId];
    }

    // 4. Strict 100% exact normalized name match
    final normName = _normalizeExactName(canonicalName);
    if (normName.isNotEmpty && catalogByName.containsKey(normName)) {
      return catalogByName[normName];
    }

    // 5. Verified 1:1 normalized name alias
    final aliasTargetId = kVerifiedNormalizedNameAliases[normName];
    if (aliasTargetId != null && catalogById.containsKey(aliasTargetId)) {
      return catalogById[aliasTargetId];
    }

    // 6. Plural / singular morphological fallback for clean catalog matches
    if (normName.length > 3 && normName.endsWith('s')) {
      final singular = normName.substring(0, normName.length - 1);
      if (catalogByName.containsKey(singular)) {
        return catalogByName[singular];
      }
      final aliasSingularId = kVerifiedNormalizedNameAliases[singular];
      if (aliasSingularId != null && catalogById.containsKey(aliasSingularId)) {
        return catalogById[aliasSingularId];
      }
    } else if (normName.isNotEmpty) {
      final plural = '${normName}s';
      if (catalogByName.containsKey(plural)) {
        return catalogByName[plural];
      }
      final aliasPluralId = kVerifiedNormalizedNameAliases[plural];
      if (aliasPluralId != null && catalogById.containsKey(aliasPluralId)) {
        return catalogById[aliasPluralId];
      }
    }

    // No exact trusted match -> return null (caller must show "Exact nutrition profile isn't available yet")
    return null;
  }

  /// Deduplicates a ranked list of [OpenVocabularyFoodCandidate] items so that
  /// duplicate IDs, duplicate canonical names, and known aliases for the same
  /// canonical concept are collapsed while preserving distinct culinary concepts
  /// (e.g., `Creamy Penne Pasta`, `Penne Alfredo`, `Creamy Pasta` remain separate,
  /// whereas `Penne Pasta`, `Penne`, `Penne Noodle Dish` collapse to `Penne Pasta`).
  static List<OpenVocabularyFoodCandidate> deduplicateCandidates(
    List<OpenVocabularyFoodCandidate> rawCandidates, {
    int maxSuggestions = 3,
    List<FoodEntity> foodCatalog = const [],
  }) {
    if (rawCandidates.isEmpty || maxSuggestions <= 0) {
      return const [];
    }

    final seenCanonicalIds = <String>{};
    final seenConceptKeys = <String>{};
    final seenResolvedFitFuelIds = <String>{};
    final deduplicated = <OpenVocabularyFoodCandidate>[];

    for (final candidate in rawCandidates) {
      final idKey = candidate.canonicalFoodId.trim().toLowerCase();
      final conceptKey = _canonicalConceptCollapseKey(candidate);
      if (idKey.isEmpty && conceptKey.isEmpty) continue;

      final resolvedFood = resolveTrustedCatalogFood(
        candidate,
        foodCatalog: foodCatalog,
      );
      final resolvedFitFuelId = resolvedFood?.id;

      // Skip if already seen by canonical ID, collapsed concept key, or resolved FitFuel ID
      if (idKey.isNotEmpty && seenCanonicalIds.contains(idKey)) {
        continue;
      }
      if (conceptKey.isNotEmpty && seenConceptKeys.contains(conceptKey)) {
        continue;
      }
      if (resolvedFitFuelId != null &&
          seenResolvedFitFuelIds.contains(resolvedFitFuelId)) {
        continue;
      }

      if (idKey.isNotEmpty) seenCanonicalIds.add(idKey);
      if (conceptKey.isNotEmpty) seenConceptKeys.add(conceptKey);
      if (resolvedFitFuelId != null) {
        seenResolvedFitFuelIds.add(resolvedFitFuelId);
      }

      // Also register all candidate aliases into seenConceptKeys so subsequent
      // alias entries for the same canonical concept are suppressed
      for (final alias in candidate.aliases) {
        final aliasKey = _normalizeAliasKey(alias);
        if (aliasKey.isNotEmpty) {
          seenConceptKeys.add(aliasKey);
        }
      }

      deduplicated.add(
        candidate.copyWith(
          rank: deduplicated.length + 1,
          inFitFuelCatalog: resolvedFood != null,
          fitFuelFoodId: resolvedFood?.id,
        ),
      );

      if (deduplicated.length >= maxSuggestions) {
        break;
      }
    }

    return deduplicated;
  }

  /// Builds a clean pre-filled search query string for a confirmed open-vocabulary
  /// food that does not yet have an exact nutrition profile in FitFuel.
  static String buildSmartSearchQuery(String foodName) {
    final cleaned = foodName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  /// Searches [foods] for [query], prioritizing culinary head nouns (e.g., `pasta`,
  /// `rice`, `chicken`, `noodles`, `salad`, `soup`, `bread`, `curry`, `paneer`, `dal`)
  /// and falling back to related culinary family catalog items when no exact match
  /// exists in FitFuel's 238 catalog.
  static List<FoodEntity> searchCatalogWithRelatedFallback({
    required List<FoodEntity> foods,
    required String query,
  }) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return foods;

    final baseResults = FoodSearchEngine.search(foods: foods, query: cleanQuery);

    // Re-score base results so culinary head nouns (like 'pasta') rank above
    // generic modifier adjectives (like 'creamy' in 'Peanut Butter Creamy')
    final queryTokens = cleanQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final expandedFamilyTerms = _expandCulinaryFamilyKeywords(queryTokens);

    final scored = <_RankedCatalogItem>[];
    for (final food in foods) {
      final nameLower = food.name.toLowerCase();
      final catLower = food.category.toLowerCase();
      int score = 0;

      if (nameLower == cleanQuery) {
        score += 200;
      } else if (nameLower.startsWith(cleanQuery)) {
        score += 100;
      } else if (nameLower.contains(cleanQuery)) {
        score += 60;
      }

      for (final token in queryTokens) {
        final isModifier = _kModifierAdjectives.contains(token);
        final weight = isModifier ? 4 : 25;
        final nameWords = nameLower
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .split(RegExp(r'\s+'));
        if (nameWords.contains(token)) {
          score += weight;
        } else if (nameWords.any((w) => w.startsWith(token) && token.length >= 3)) {
          score += (weight ~/ 2);
        }
        if (!isModifier && catLower.contains(token)) {
          score += 10;
        }
      }

      for (final familyTerm in expandedFamilyTerms) {
        if (nameLower.contains(familyTerm)) {
          score += 20;
        }
      }

      if (score > 0) {
        scored.add(_RankedCatalogItem(food: food, score: score));
      }
    }

    if (scored.isNotEmpty) {
      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.map((e) => e.food).toList();
    }

    return baseResults;
  }

  static const Set<String> _kModifierAdjectives = {
    'creamy',
    'fresh',
    'crispy',
    'spicy',
    'sweet',
    'hot',
    'cold',
    'homemade',
    'classic',
    'traditional',
    'baked',
    'fried',
    'grilled',
    'steamed',
    'roasted',
    'bowl',
    'plate',
    'style',
  };

  static Set<String> _expandCulinaryFamilyKeywords(List<String> tokens) {
    final related = <String>{};
    for (final t in tokens) {
      switch (t) {
        case 'penne':
        case 'alfredo':
        case 'spaghetti':
        case 'fettuccine':
        case 'macaroni':
        case 'lasagna':
        case 'ravioli':
        case 'gnocchi':
        case 'carbonara':
        case 'bolognese':
        case 'pesto':
        case 'linguine':
        case 'tagliatelle':
        case 'rigatoni':
        case 'fusilli':
        case 'pasta':
          related.add('pasta');
          break;
        case 'ramen':
        case 'tsukemen':
        case 'udon':
        case 'soba':
        case 'pho':
        case 'noodle':
        case 'noodles':
        case 'chow':
        case 'hakka':
        case 'lo':
        case 'pad':
          related.addAll(['noodle', 'soup', 'pasta']);
          break;
        case 'burger':
        case 'sandwich':
        case 'panini':
        case 'sub':
        case 'baguette':
        case 'banh':
        case 'shawarma':
        case 'burrito':
        case 'taco':
        case 'tacos':
        case 'quesadilla':
        case 'wrap':
          related.addAll(['wrap', 'bread', 'toast', 'chicken', 'salad']);
          break;
        case 'pizza':
        case 'flammkuchen':
        case 'flatbread':
        case 'naan':
        case 'kulcha':
        case 'paratha':
          related.addAll(['roti', 'chapati', 'paratha', 'bread']);
          break;
      }
    }
    return related;
  }

  static String _normalizeExactName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeAliasKey(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _kAliasDuplicateCollapseMap[cleaned] ?? cleaned;
  }

  static String _canonicalConceptCollapseKey(
    OpenVocabularyFoodCandidate candidate,
  ) {
    final byName = _normalizeAliasKey(candidate.canonicalName);
    if (byName.isNotEmpty) return byName;
    return candidate.canonicalFoodId.toLowerCase().trim();
  }
}

class _RankedCatalogItem {
  final FoodEntity food;
  final int score;

  const _RankedCatalogItem({required this.food, required this.score});
}
