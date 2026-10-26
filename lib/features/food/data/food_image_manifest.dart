// Centralized Food Image Manifest for FitFuel
// Audited and expanded in Phase 35.7.1 (Truthful + High-Quality + Production-Safe)

class FoodImageRecord {
  final String imagePathOrUrl;
  final String source;
  final String license;

  const FoodImageRecord({
    required this.imagePathOrUrl,
    this.source = 'Unsplash',
    this.license = 'Free to use under the Unsplash License',
  });
}

class FoodImageManifest {
  static const Map<String, FoodImageRecord> manifest = {
    'predefined_idli': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/idli.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_dosa': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_masala_dosa': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_rava_dosa': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/rava_dosa.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_uttapam': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/uttapam.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_upma': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/upma.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_poha': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/poha.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_pongal': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pongal.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_pesarattu': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pesarattu.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_appam': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/appam.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_aloo_paratha': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/aloo_paratha.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_paneer_paratha': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_gobhi_paratha': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/gobhi_paratha.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_chapati': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/chapati.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_roti': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/roti.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_poori': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/poori.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.5',
    ),
    'predefined_medu_vada': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/medu_vada.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.0',
    ),
    'predefined_sabudana_khichdi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sabudana_khichdi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_dhokla': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/dhokla.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_rava_upma': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/upma.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_steamed_rice': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1516684732162-798a0062be99?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_brown_rice_ind': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_jeera_rice': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/jeera_rice.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_lemon_rice': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_tomato_rice': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_curd_rice': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_veg_biryani': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/veg_biryani.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_chicken_biryani': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_egg_biryani': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/egg_biryani.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_mutton_biryani': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_veg_pulao': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_chicken_pulao': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_khichdi_ind': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_kadhi_chawal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_rajma_chawal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_dal_tadka': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/dal_tadka.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_dal_fry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/dal_fry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_moong_dal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_masoor_dal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_toor_dal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_chana_dal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_rajma_curry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/rajma_curry.webp',
      source: 'Wikimedia Commons',
      license: 'CC0',
    ),
    'predefined_chole_masala': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_black_chana_curry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/black_chana_curry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_green_gram_whole': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_sprouted_moong_salad': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_palak_paneer': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1613292443284-8d10ef9383fe?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_aloo_gobi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/aloo_gobi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.0',
    ),
    'predefined_bhindi_masala': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_baingan_bharta': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_mixed_veg_curry': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_veg_kurma': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_sambar': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sambar.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_rasam': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_cabbage_poriyal': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/cabbage_poriyal.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_beans_thoran': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_carrot_methi': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_lauki_curry': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_aloo_methi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/aloo_methi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_dum_aloo': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_bhindi_fry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/bhindi_fry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_ind_grilled_chicken': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_chicken_curry': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_tandoori_chicken': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_chicken_tikka': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_chicken_kebab': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/chicken_kebab.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_boiled_egg_salad': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_egg_omelette': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/egg_omelette.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_egg_bhurji': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/egg_bhurji.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_egg_curry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/egg_curry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_fish_curry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/fish_curry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_grilled_fish_tikka': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/amritsari_fish_tikka.webp',
      source: 'Wikimedia Commons',
      license: 'CC0',
    ),
    'predefined_salmon_tikka': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_prawn_masala': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_mutton_curry': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_butter_chicken': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_curd': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/curd.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_greek_yogurt_mint': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_ind_paneer': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_low_fat_paneer': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_buttermilk': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_sweet_lassi': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_mango_lassi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/mango_lassi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_paneer_bhurji': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_roasted_chana': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_peanut_chaat': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_sprouts_chaat': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_bhel_puri': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/bhel_puri.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.0',
    ),
    'predefined_samosa': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_veg_pakora': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/veg_pakora.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_khandvi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/khandvi.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_murukku': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/murukku.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_rice_kheer': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/rice_kheer.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.0',
    ),
    'predefined_gulab_jamun': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/gulab_jamun.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_rasgulla': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/rasgulla.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_jalebi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/jalebi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_gajar_halwa': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/gajar_halwa.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_besan_ladoo': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_coconut_ladoo': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/coconut_ladoo.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_apple': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_banana': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_orange': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1547514701-42782101795e?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_mango': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1553279768-865429fa0078?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_papaya': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1526318896980-cf78c088247c?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_watermelon': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_muskmelon': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/muskmelon.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_pineapple': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_grapes': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/grapes.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_guava': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/guava.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_pomegranate': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pomegranate.webp',
      source: 'Wikimedia Commons',
      license: 'GFDL 1.2',
    ),
    'predefined_kiwi': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/kiwi.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.5',
    ),
    'predefined_strawberry': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_blueberry': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1498557850523-fd3d118b962e?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_raspberry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/raspberry.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_pear': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pear.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_peach': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/peach.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_plum': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/plum.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_chikoo': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/chikoo.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_fresh_coconut': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_jackfruit': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_dragon_fruit': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/dragon_fruit.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_avocado': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_lemon': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/lemon.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_sweet_lime': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sweet_lime.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_cherries': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/cherries.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_fig': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/fig.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_blackberry': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/blackberry.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_potato': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_sweet_potato': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sweet_potato.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 3.0',
    ),
    'predefined_tomato': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1595855759920-86582396756a?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_onion': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_carrot': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_beetroot': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/beetroot.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_spinach': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_broccoli': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_cauliflower': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/cauliflower.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_cabbage': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/cabbage.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_cucumber': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_capsicum': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/capsicum.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_green_beans': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/green_beans.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_green_peas': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/green_peas.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_sweet_corn': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sweet_corn.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_pumpkin': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pumpkin.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_bottle_gourd': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/bottle_gourd.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_bitter_gourd': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_ridge_gourd': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_eggplant': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/eggplant.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_okra': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_mushroom': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_lettuce': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/lettuce.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_zucchini': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_kale': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/kale.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_asparagus': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/asparagus.webp',
      source: 'Wikimedia Commons',
      license: 'CC0',
    ),
    'predefined_garlic': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/garlic.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 3.0',
    ),
    'predefined_ginger': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/ginger.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_oats': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_oatmeal_cooked': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_quinoa': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_brown_rice_grain': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_white_rice_grain': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_whole_wheat_flour': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_whole_wheat_bread': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_multigrain_bread': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_ragi_millet': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_bajra_millet': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_jowar_millet': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_barley': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_corn_meal': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_couscous': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_basmati_rice': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_oats_bran': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_rice_cakes': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_almonds': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_walnuts': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/walnuts.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_cashews': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/cashews.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_pistachios': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pistachios.webp',
      source: 'Wikimedia Commons',
      license: 'GFDL 1.2',
    ),
    'predefined_peanuts': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/peanuts.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_brazil_nuts': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/brazil_nuts.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_hazelnuts': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/hazelnuts.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_chia_seeds': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/chia_seeds.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_flax_seeds': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/flax_seeds.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_pumpkin_seeds': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pumpkin_seeds.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 3.0',
    ),
    'predefined_sunflower_seeds': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/sunflower_seeds.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_sesame_seeds': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_peanut_butter': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/peanut_butter.webp',
      source: 'Wikimedia Commons',
      license: 'CC0',
    ),
    'predefined_almond_butter': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/almond_butter.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 2.0',
    ),
    'predefined_tahini': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/tahini.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_pecans': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/pecans.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_chia_pudding': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/chia_pudding.webp',
      source: 'Wikimedia Commons',
      license: 'CC0',
    ),
    'predefined_grilled_chicken_breast': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_turkey_breast': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/turkey_breast.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY 4.0',
    ),
    'predefined_canned_tuna': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1501595091296-3aa970afb3ff?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_grilled_salmon': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_steamed_shrimp': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/steamed_shrimp.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_beef_steak': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/beef_steak.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_firm_tofu': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/firm_tofu.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_tempeh': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_greek_yogurt_plain': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_cottage_cheese': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_scrambled_eggs': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/scrambled_eggs.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_hard_boiled_eggs': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/hard_boiled_eggs.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 2.0',
    ),
    'predefined_protein_oatmeal': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_overnight_oats': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_chicken_salad': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1781332149415-f420708ab98f?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_tuna_salad': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_caesar_salad': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/caesar_salad.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_mixed_veg_salad': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_quinoa_salad': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_classic_hummus': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_whole_grain_pasta': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_standard_pasta': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_baked_sweet_potato': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/baked_sweet_potato.webp',
      source: 'Wikimedia Commons',
      license: 'Public domain',
    ),
    'predefined_baked_potato': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/baked_potato.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_honey_granola': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_pb_toast': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_avocado_toast': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_berry_smoothie': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_protein_smoothie': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1707219811295-0f283760668b?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_whey_protein_shake': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1579722821273-0f6c7d44362f?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_veg_soup': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_chicken_soup': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_egg_white_omelette': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1786213591036-96b02dbff18e?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_chicken_wrap': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_protein_bar': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1622484216802-0e5f5f4b5242?auto=format&fit=crop&w=600&q=80',
      source: 'Unsplash',
      license: 'Free to use under the Unsplash License',
    ),
    'predefined_mineral_water': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_coconut_water': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/coconut_water.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_low_fat_milk': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_spiced_buttermilk': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
    'predefined_green_tea': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_black_tea': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_filter_coffee': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/filter_coffee.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 3.0',
    ),
    'predefined_black_coffee': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/black_coffee.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_fresh_orange_juice': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_lemon_water': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_tomato_juice': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/tomato_juice.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_matcha_tea': FoodImageRecord(
      imagePathOrUrl: 'assets/images/foods/matcha_tea.webp',
      source: 'Wikimedia Commons',
      license: 'CC BY-SA 4.0',
    ),
    'predefined_paneer_tikka': FoodImageRecord(
      imagePathOrUrl: 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80',
    ),
    'predefined_fish_fry': FoodImageRecord(
      imagePathOrUrl: '',
      source: 'FitFuel Branded Fallback',
      license: 'FitFuel Open Design System',
    ),
  };
}
