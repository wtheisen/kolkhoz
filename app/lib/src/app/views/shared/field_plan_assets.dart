import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';

const fieldPlanBrigadePlotBackgroundPath =
    'assets/art/field_plan/game/backgrounds/brigade-plot-light.png';
const fieldPlanFieldsBackgroundPath =
    'assets/art/field_plan/game/backgrounds/fields-light.png';
const fieldPlanNorthBackgroundPath =
    'assets/art/field_plan/game/backgrounds/north-light.png';

const fieldPlanSignAssetPath =
    'assets/art/field_plan/shared/signs/field-sign.png';

const fieldPlanPlantedSunflowerPath =
    'assets/art/field_plan/cards/planted/pip-sunflower-isometric.png';
const fieldPlanPlantedSunflowerMipPath =
    'assets/art/field_plan/cards/planted/pip-sunflower-isometric-mip.png';
const fieldPlanCardBackAssetPath =
    'assets/art/field_plan/cards/backs/card-back-kolkhoz.png';

String fieldPlanCardFrameAssetPath({
  required String suit,
  required bool trump,
  bool dark = false,
}) {
  final name = trump ? 'trump' : suit;
  final suffix = dark ? '-dark' : '';
  return 'assets/art/field_plan/cards/frames/card-frame-$name$suffix.png';
}

const fieldPlanCardSuitAssetPaths = <String, String>{
  'wheat': 'assets/art/field_plan/cards/suits/suit-wheat.png',
  'sunflower': 'assets/art/field_plan/cards/suits/suit-sunflower.png',
  'potato': 'assets/art/field_plan/cards/suits/suit-potato.png',
  'beet': 'assets/art/field_plan/cards/suits/suit-beet.png',
  'wrecker': 'assets/art/field_plan/cards/suits/suit-all.png',
};

const fieldPlanCardSuitMipAssetPaths = <String, String>{
  'wheat': 'assets/art/field_plan/cards/suits/mip/suit-wheat.png',
  'sunflower': 'assets/art/field_plan/cards/suits/mip/suit-sunflower.png',
  'potato': 'assets/art/field_plan/cards/suits/mip/suit-potato.png',
  'beet': 'assets/art/field_plan/cards/suits/mip/suit-beet.png',
};

String? fieldPlanCardSuitAssetPath(String suit, {bool mip = false}) => mip
    ? fieldPlanCardSuitMipAssetPaths[suit]
    : fieldPlanCardSuitAssetPaths[suit];

String? fieldPlanCardFaceAssetPath({
  required String suit,
  required String rank,
  required bool nomenclature,
}) {
  if (suit == 'wrecker') {
    return 'assets/art/field_plan/cards/faces/face-saboteur.png';
  }
  if (!fieldPlanCardSuitAssetPaths.containsKey(suit) ||
      (rank != 'jack' && rank != 'queen' && rank != 'king')) {
    return null;
  }
  final suffix = nomenclature ? '-nomenklatura' : '';
  return 'assets/art/field_plan/cards/faces/face-$rank-$suit$suffix.png';
}

const fieldPlanCardArtAssetPaths = <String>[
  fieldPlanCardBackAssetPath,
  'assets/art/field_plan/cards/frames/card-frame-wheat.png',
  'assets/art/field_plan/cards/frames/card-frame-sunflower.png',
  'assets/art/field_plan/cards/frames/card-frame-potato.png',
  'assets/art/field_plan/cards/frames/card-frame-beet.png',
  'assets/art/field_plan/cards/frames/card-frame-trump.png',
  'assets/art/field_plan/cards/frames/card-frame-wheat-dark.png',
  'assets/art/field_plan/cards/frames/card-frame-sunflower-dark.png',
  'assets/art/field_plan/cards/frames/card-frame-potato-dark.png',
  'assets/art/field_plan/cards/frames/card-frame-beet-dark.png',
  'assets/art/field_plan/cards/frames/card-frame-trump-dark.png',
  fieldPlanPlantedSunflowerPath,
  fieldPlanPlantedSunflowerMipPath,
  'assets/art/field_plan/cards/suits/suit-wheat.png',
  'assets/art/field_plan/cards/suits/suit-sunflower.png',
  'assets/art/field_plan/cards/suits/suit-potato.png',
  'assets/art/field_plan/cards/suits/suit-beet.png',
  'assets/art/field_plan/cards/suits/suit-all.png',
  'assets/art/field_plan/cards/suits/mip/suit-wheat.png',
  'assets/art/field_plan/cards/suits/mip/suit-sunflower.png',
  'assets/art/field_plan/cards/suits/mip/suit-potato.png',
  'assets/art/field_plan/cards/suits/mip/suit-beet.png',
  'assets/art/field_plan/cards/faces/face-jack-wheat.png',
  'assets/art/field_plan/cards/faces/face-jack-sunflower.png',
  'assets/art/field_plan/cards/faces/face-jack-potato.png',
  'assets/art/field_plan/cards/faces/face-jack-beet.png',
  'assets/art/field_plan/cards/faces/face-queen-wheat.png',
  'assets/art/field_plan/cards/faces/face-queen-sunflower.png',
  'assets/art/field_plan/cards/faces/face-queen-potato.png',
  'assets/art/field_plan/cards/faces/face-queen-beet.png',
  'assets/art/field_plan/cards/faces/face-king-wheat.png',
  'assets/art/field_plan/cards/faces/face-king-sunflower.png',
  'assets/art/field_plan/cards/faces/face-king-potato.png',
  'assets/art/field_plan/cards/faces/face-king-beet.png',
  'assets/art/field_plan/cards/faces/face-jack-wheat-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-jack-sunflower-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-jack-potato-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-jack-beet-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-queen-wheat-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-queen-sunflower-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-queen-potato-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-queen-beet-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-king-wheat-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-king-sunflower-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-king-potato-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-king-beet-nomenklatura.png',
  'assets/art/field_plan/cards/faces/face-saboteur.png',
  'assets/art/field_plan/cards/ranks/rank-saboteur-star.png',
];

const fieldPlanCreateGamePictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/create-game.png',
);
const fieldPlanJoinGamePictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/join-game.png',
);
const fieldPlanHowToPlayPictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/how-to-play.png',
);
const fieldPlanLanguagePictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/language.png',
);
const fieldPlanAppearancePictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/appearance.png',
);
const fieldPlanSettingsPictogram = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/settings.png',
);

const fieldPlanGlobalNavigationPictograms = <ArtAssetRef>[
  fieldPlanCreateGamePictogram,
  fieldPlanJoinGamePictogram,
  fieldPlanHowToPlayPictogram,
  fieldPlanLanguagePictogram,
  fieldPlanAppearancePictogram,
  fieldPlanSettingsPictogram,
];

const fieldPlanPresetKolkhoz = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_kolkhoz.png',
);
const fieldPlanPresetLittleKolkhoz = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/presets/preset_little_kolkhoz.png',
);
const fieldPlanPresetCampStyle = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_camp_style.png',
);
const fieldPlanPresetCustom = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_custom.png',
);

const fieldPlanVariantDeck = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_deck.png',
);
const fieldPlanVariantFiveYearPlan = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_five_year_plan.png',
);
const fieldPlanVariantSwapCards = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_swap_cards.png',
);
const fieldPlanVariantPassCards = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_pass_cards.png',
);
const fieldPlanVariantFinalYearTrump = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_final_year_trump.png',
);
const fieldPlanVariantHighestCardsRequisition = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_highest_cards_requisition.png',
);
const fieldPlanVariantLottoRewards = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_lotto_rewards.png',
);
const fieldPlanVariantStakhanovite = ArtAssetRef(
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_stakhanovite.png',
);
const fieldPlanVariantSaboteur = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_saboteur.png',
);

const fieldPlanLedgerIllustrations = <ArtAssetRef>[
  fieldPlanPresetKolkhoz,
  fieldPlanPresetLittleKolkhoz,
  fieldPlanPresetCampStyle,
  fieldPlanPresetCustom,
  fieldPlanVariantDeck,
  fieldPlanVariantFiveYearPlan,
  fieldPlanVariantSwapCards,
  fieldPlanVariantPassCards,
  fieldPlanVariantFinalYearTrump,
  fieldPlanVariantHighestCardsRequisition,
  fieldPlanVariantLottoRewards,
  fieldPlanVariantStakhanovite,
  fieldPlanVariantSaboteur,
];

const fieldPlanSaveFavorite = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/save-favorite.png',
);
const fieldPlanLoadFavorite = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/load-favorite.png',
);
const fieldPlanGoToLobby = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/go-to-lobby.png',
);

const fieldPlanLedgerActions = <ArtAssetRef>[
  fieldPlanSaveFavorite,
  fieldPlanLoadFavorite,
  fieldPlanGoToLobby,
];

const fieldPlanPlayerForewoman = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/game/players/forewoman.png',
);
const fieldPlanPlayerMechanic = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/game/players/mechanic.png',
);
const fieldPlanPlayerAgronomist = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/game/players/agronomist.png',
);
const fieldPlanPlayerBeekeeper = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/game/players/beekeeper.png',
);

const fieldPlanPlayerPortraits = <ArtAssetRef>[
  fieldPlanPlayerForewoman,
  fieldPlanPlayerMechanic,
  fieldPlanPlayerAgronomist,
  fieldPlanPlayerBeekeeper,
];
