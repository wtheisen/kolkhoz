# Static-poster main menu asset list

Reference concept:
`design/field-plan-world/mockups/main-menu-static-hero-concept-v1.png`

The menu should follow the same ownership rule as the static gameplay panels:
one cohesive raster underlay plus a small set of flexible printed-chrome
underlays. Labels, icons, profile data, focus treatment, and online status stay
live in Flutter. No Figma source is required for this static path.

## Minimum new artwork

| ID | Proposed runtime file | Size | Purpose | Artwork requirements |
| --- | --- | --- | --- | --- |
| MM01 | `app/assets/art/field_plan/menu/main-menu-underlay-v1.png` | 2560 x 1440 master, 16:9 | Full-screen menu backdrop | Warm collective-farm panorama matching the Brigade and Fields underlays. Card-free and text-free. Preserve a low-detail area behind the left 40% navigation stack, the upper-right profile badge, and the lower-right daily poster. Keep important faces, vehicles, flags, and architecture outside those zones. |
| MM02 | `app/assets/art/field_plan/menu/daily-plan-tractor-v1.png` | 640 x 480 | Illustration inside the daily-challenge poster | Tractor and worker in the same printed style. Art only: no heading, button, date, score, or border. The crop must survive both the tall desktop poster and a shallow compact strip. |

MM01 is the only essential full-screen raster. MM02 can initially be omitted and
replaced with a crop from MM01, but a dedicated illustration will give the daily
challenge enough contrast to read as a separate action.

## Minimum flexible poster chrome

These are raster assets too. Flutter should stretch them with the existing
nine-slice painter so the printed borders, ink wear, and offset shadows survive
at arbitrary button widths. Each source needs a broad, quiet center region and
fixed corners/caps.

| ID | Proposed runtime file | Source size | Slice contract | Purpose |
| --- | --- | --- | --- | --- |
| MC01 | `app/assets/art/field_plan/menu/chrome/menu-action-neutral-v1.png` | 1200 x 256 | left 96, top 64, right 192, bottom 64 | Cream main-action placard with charcoal border, narrow scarlet accent, and a transparent notched/arrow right cap. |
| MC02 | `app/assets/art/field_plan/menu/chrome/menu-action-primary-v1.png` | 1200 x 256 | same as MC01 | Scarlet selected-action placard with cream border/type field and the identical silhouette. |
| MC03 | `app/assets/art/field_plan/menu/chrome/menu-utility-charcoal-v1.png` | 1024 x 224 | 72 on all sides | Charcoal strip for Profile, Settings, language, and appearance utilities. Must stretch from one compact icon button to the two-label footer shown in the mockup. |
| MC04 | `app/assets/art/field_plan/menu/chrome/menu-title-banner-v1.png` | 1536 x 512 | left 128, top 96, right 256, bottom 96 | Text-free cream title banner with charcoal offset shadow, upper-left diagonal crop, star, and short rule ornaments. The center remains clear for live title/subtitle text. |
| MC05 | `app/assets/art/field_plan/menu/chrome/menu-profile-badge-v1.png` | 1024 x 256 | left/right 128, top/bottom 64 | Charcoal profile badge with a fixed circular portrait aperture on the left and a stretchable name/status field. |
| MC06 | `app/assets/art/field_plan/menu/chrome/menu-daily-poster-frame-v1.png` | 768 x 960 | 96 on all sides | Text-free cream poster/frame with restrained uneven border, printed shadow, and optional pin. Live illustration, heading, status, and button sit inside it. |

MC01 and MC02 are state variants of one exact silhouette. Do not independently
generate their geometry. Create the neutral source first, then recolor/edit it
to primary so buttons do not jump when selection changes.

The repo already contains stretchable Field Plan assets:

- `app/assets/art/field_plan/ledger/underlays/ledger-neutral.png`;
- `app/assets/art/field_plan/ledger/underlays/ledger-primary.png`;
- `PrintedUnderlay` and `ChromeNineSlicePainter`.

Those are good implementation references and can temporarily cover rectangular
controls. They do not supply the mockup's arrow cap, title-banner silhouette,
profile aperture, charcoal utility strip, or poster frame, so they are not the
complete visual kit.

### State ownership

Only neutral and primary colorways need authored raster files. Flutter should
derive the remaining states:

- hover: warm highlight wash plus a slight lift;
- keyboard/gamepad focus: explicit high-contrast outer keyline;
- pressed: translate down 1-2 logical pixels and apply a darker color wash;
- disabled: opacity/desaturation plus disabled semantics;
- loading: live progress mark over the unchanged underlay.

Do not generate separate hover, pressed, disabled, loading, English, or Russian
button rasters.

## Optional artwork

| ID | Proposed runtime file | Size | Purpose | When to make it |
| --- | --- | --- | --- | --- |
| MM03 | `app/assets/art/field_plan/menu/main-menu-underlay-winter-v1.png` | 2560 x 1440 | Dark/winter appearance variant | Only if appearance switching should materially change the scene. Do not make this for the first implementation; a Flutter color treatment over MM01 is sufficient for initial dark-mode testing. |
| MM04 | `app/assets/art/field_plan/menu/daily-plan-harvest-v1.png` | 640 x 480 | Alternate daily-poster illustration | Add when the daily challenge has rotation or seasonal identity. |
| MM05 | `app/assets/art/field_plan/menu/menu-print-wear-overlay-v1.png` | 1024 x 1024, seamless | Shared scratches and uneven ink | Only if the live Flutter placards look too clean beside MM01. Prefer the existing paper texture first. |

## Existing assets to reuse

These are already large enough for the proposed menu and should be evaluated in
place before creating replacements:

| Role | Existing asset |
| --- | --- |
| Create/local-game icon | `app/assets/ui/Icons/icon-create-game.png` |
| Join/online-game icon | `app/assets/ui/Icons/icon-join-game.png` |
| How-to-play icon/character | `app/assets/ui/Icons/icon-foreman-misha.png` |
| Profile utility icon | `app/assets/ui/Icons/icon-profile.png` |
| Settings utility icon | `app/assets/ui/Icons/icon-gears.png` |
| Star ornament | `app/assets/ui/Icons/icon-medal-star.png` |
| Language controls | `app/assets/ui/Icons/icon-language-en.png`, `icon-language-ru.png` |
| Appearance controls | `app/assets/ui/Icons/icon-appearance-light.png`, `icon-appearance-dark.png` |
| Profile portraits | `app/assets/art/field_plan/game/players/*.png` |
| Paper grain | `app/assets/art/field_plan/shared/textures/paper-light.png` |
| Display type | `PTSansNarrow` fonts already declared in `app/pubspec.yaml` |
| Body type | `PTSans` fonts already declared in `app/pubspec.yaml` |

The current 512 x 512 menu icons may still feel more like the older pixel UI
than the new poster panels. That is a visual-review question, not an automatic
asset-generation task. If they clash, replace them as one coordinated five-icon
set rather than redrawing them piecemeal.

## Keep these live in Flutter

Do **not** bake any of the following into MM01 or MM02:

- `KOLKHOZ` and the subtitle;
- Create Game, Join Game, and How to Play labels;
- selected, hover, pressed, disabled, loading, or focus states;
- profile portrait, display name, cloud state, or notification badge;
- daily challenge title, date, status, score, or call-to-action;
- language and appearance controls;
- localized English or Russian copy.

Flutter owns the layout and stretching of the title banner, navigation
placards, profile badge, utility strip, and daily-poster frame, but their
printed edges and surface character come from MC01-MC06. Live Flutter overlays
own labels, icons, state washes, focus rings, and hit targets. This keeps the
screen responsive without reducing the mockup to sterile vector rectangles.

## Responsive crop contract for MM01

One 16:9 master should cover the supported landscape sizes if it is authored
with these protected regions:

- left navigation safe area: `x = 2%-41%`, `y = 29%-94%`;
- title safe area: `x = 0%-48%`, `y = 0%-32%`;
- profile safe area: `x = 73%-98%`, `y = 3%-19%`;
- daily-poster safe area: `x = 77%-98%`, `y = 62%-96%`;
- primary scene focus: `x = 42%-77%`, `y = 20%-88%`.

On compact landscape phones, hide the daily poster first, reduce the profile
badge to a portrait button, and shorten the title subtitle. Do not author a
second phone background unless real-device cropping proves the shared master
cannot preserve the scene.

## Asset production order

1. Generate and approve MM01 without any UI or text.
2. Author MC01, derive MC02 from it, and prove both through the existing
   nine-slice painter at several widths.
3. Author MC03-MC05 and compose the real Flutter menu using existing icons and
   portraits.
4. Test phone landscape, tablet, and desktop crops.
5. Lock the daily-poster aperture, then author MC06 and MM02.
6. Review the existing five menu icons together and replace the set only if it
   visibly conflicts with the poster treatment.
7. Consider MM03-MM05 only after the minimum menu is working.

## Acceptance checks

- MM01 reads as the same world as the production Brigade and Fields panels.
- Every text string remains live and localizable.
- Buttons meet the existing hit-target and keyboard-focus requirements.
- The backdrop does not compete with navigation labels at any supported size.
- The profile and daily sections work with missing/offline/loading data.
- No essential action depends on baked raster text.
- MC01 and MC02 preserve identical outer geometry at every tested width.
- Nine-slice stretching does not distort corners, arrow caps, paper grain, or
  printed shadows.
- Raster files are precached before the first menu frame to avoid a beige or
  blank flash.
