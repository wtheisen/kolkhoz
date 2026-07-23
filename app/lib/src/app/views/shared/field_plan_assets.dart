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
}) => trump
    ? 'assets/art/field_plan/cards/frames/card-frame-trump.png'
    : 'assets/art/field_plan/cards/frames/card-frame-$suit.png';

String fieldPlanPlantedCardFacePath(int seatID) =>
    'assets/art/field_plan/cards/planted/seat-$seatID.png';

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
  return 'assets/art/field_plan/cards/faces/face-$rank-$suit.png';
}

const fieldPlanCardArtAssetPaths = <String>[
  fieldPlanCardBackAssetPath,
  'assets/art/field_plan/cards/frames/card-frame-wheat.png',
  'assets/art/field_plan/cards/frames/card-frame-sunflower.png',
  'assets/art/field_plan/cards/frames/card-frame-potato.png',
  'assets/art/field_plan/cards/frames/card-frame-beet.png',
  'assets/art/field_plan/cards/frames/card-frame-trump.png',
  fieldPlanPlantedSunflowerPath,
  fieldPlanPlantedSunflowerMipPath,
  'assets/art/field_plan/cards/planted/seat-0.png',
  'assets/art/field_plan/cards/planted/seat-1.png',
  'assets/art/field_plan/cards/planted/seat-2.png',
  'assets/art/field_plan/cards/planted/seat-3.png',
  'assets/art/field_plan/cards/planted/frame-paper-overlay.png',
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
  'assets/art/field_plan/cards/faces/face-saboteur.png',
  'assets/art/field_plan/cards/ranks/rank-saboteur-star.png',
];

const fieldPlanCreateGamePictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-create-game.png',
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/create-game.png',
);
const fieldPlanJoinGamePictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-join-game.png',
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/join-game.png',
);
const fieldPlanHowToPlayPictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-rules-scroll.png',
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/how-to-play.png',
);
const fieldPlanLanguagePictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-language.png',
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/language.png',
);
const fieldPlanAppearancePictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-appearance.png',
  fieldPlanPath: 'assets/art/field_plan/shared/pictograms/appearance.png',
);
const fieldPlanSettingsPictogram = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-settings-session.png',
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
  legacyPath: 'assets/ui/Icons/icon-preset-kolkhoz.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_kolkhoz.png',
);
const fieldPlanPresetLittleKolkhoz = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-preset-little-kolkhoz.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/presets/preset_little_kolkhoz.png',
);
const fieldPlanPresetCampStyle = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-preset-camp-style.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_camp_style.png',
);
const fieldPlanPresetCustom = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-settings-display.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/presets/preset_custom.png',
);

const fieldPlanVariantDeck = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-variant-deck-52.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_deck.png',
);
const fieldPlanVariantFiveYearPlan = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-year-5.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_five_year_plan.png',
);
const fieldPlanVariantSwapCards = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-variant-swap.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_swap_cards.png',
);
const fieldPlanVariantPassCards = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-pass.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/variants/variant_pass_cards.png',
);
const fieldPlanVariantFinalYearTrump = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-final-year-trump.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_final_year_trump.png',
);
const fieldPlanVariantHighestCardsRequisition = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-highest-cards-requisition.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_highest_cards_requisition.png',
);
const fieldPlanVariantLottoRewards = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-lotto-rewards.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_lotto_rewards.png',
);
const fieldPlanVariantStakhanovite = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-variant-accumulation.png',
  fieldPlanPath:
      'assets/art/field_plan/ledger/variants/variant_stakhanovite.png',
);
const fieldPlanVariantSaboteur = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-variant-saboteur.png',
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
  legacyPath: 'assets/ui/Icons/icon-save.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/save-favorite.png',
);
const fieldPlanLoadFavorite = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-save.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/load-favorite.png',
);
const fieldPlanGoToLobby = ArtAssetRef(
  legacyPath: 'assets/ui/Icons/icon-add-friend.png',
  fieldPlanPath: 'assets/art/field_plan/ledger/actions/go-to-lobby.png',
);

const fieldPlanLedgerActions = <ArtAssetRef>[
  fieldPlanSaveFavorite,
  fieldPlanLoadFavorite,
  fieldPlanGoToLobby,
];

const fieldPlanPlayerForewoman = ArtAssetRef(
  legacyPath: 'assets/ui/worker1.png',
  fieldPlanPath: 'assets/art/field_plan/game/players/forewoman.png',
);
const fieldPlanPlayerMechanic = ArtAssetRef(
  legacyPath: 'assets/ui/worker2.png',
  fieldPlanPath: 'assets/art/field_plan/game/players/mechanic.png',
);
const fieldPlanPlayerAgronomist = ArtAssetRef(
  legacyPath: 'assets/ui/worker3.png',
  fieldPlanPath: 'assets/art/field_plan/game/players/agronomist.png',
);
const fieldPlanPlayerBeekeeper = ArtAssetRef(
  legacyPath: 'assets/ui/worker4.png',
  fieldPlanPath: 'assets/art/field_plan/game/players/beekeeper.png',
);

const fieldPlanPlayerPortraits = <ArtAssetRef>[
  fieldPlanPlayerForewoman,
  fieldPlanPlayerMechanic,
  fieldPlanPlayerAgronomist,
  fieldPlanPlayerBeekeeper,
];
