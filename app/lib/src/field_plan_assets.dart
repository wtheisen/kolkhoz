import 'art_direction.dart';

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

String fieldPlanPlantedCardFacePath(int seatID) =>
    'assets/art/field_plan/cards/planted/seat-$seatID.png';

const fieldPlanCardSuitAssetPaths = <String, String>{
  'wheat': 'assets/art/field_plan/cards/suits/suit-wheat.png',
  'sunflower': 'assets/art/field_plan/cards/suits/suit-sunflower.png',
  'potato': 'assets/art/field_plan/cards/suits/suit-potato.png',
  'beet': 'assets/art/field_plan/cards/suits/suit-beet.png',
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
  if (nomenclature || !fieldPlanCardSuitAssetPaths.containsKey(suit)) {
    return null;
  }
  if (rank != 'jack' && rank != 'queen') {
    return null;
  }
  return 'assets/art/field_plan/cards/faces/face-$rank-$suit.png';
}

const fieldPlanCardArtAssetPaths = <String>[
  fieldPlanCardBackAssetPath,
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
