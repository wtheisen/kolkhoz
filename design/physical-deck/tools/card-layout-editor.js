const CARD = { width: 1644, height: 2244 };
const STORAGE_KEY = "kolkhoz-card-layout-editor-v1";
const RANK_METRIC_SIZE = 1000;
const CARD_FONT_FAMILY = '"Kolkhoz Podkova", Georgia, serif';
const ZERO_FONT_FAMILY = '"Kolkhoz Bitter", Georgia, serif';
const rankMetricCanvas = document.createElement("canvas");
const rankMetricContext = rankMetricCanvas.getContext("2d");

const suitDefinitions = [
  { id: "wheat", label: "Wheat", pipHref: "../pips/wheat/suit-wheat-poster-c-v1.png" },
  { id: "sunflower", label: "Sunflower", pipHref: "../pips/sunflower/suit-sunflower-poster-v1.png" },
  { id: "potato", label: "Potato", pipHref: "../pips/potato/suit-potato-poster-v1.png" },
  { id: "beet", label: "Beet", pipHref: "../pips/beet/suit-beet-poster-v1.png" }
];

const artworkPlateHrefs = {
  wheat: "../proofs/generated-borders/wheat-artwork-plate-v4-mpc.png",
  sunflower: "../proofs/generated-borders/sunflower-artwork-plate-v3-mpc.png",
  potato: "../proofs/generated-borders/potato-artwork-plate-v3-mpc.png",
  beet: "../proofs/generated-borders/beet-artwork-plate-v3-mpc.png"
};
const trumpArtworkHref = "../proofs/generated-borders/trump-inset-tile-v2-flat-red.png";
const trumpArtworkRotatedHref = "../proofs/generated-borders/trump-inset-tile-v2-flat-red-rotated.png";

const faceRankDefinitions = [
  { key: "jack", label: "Jack", rank: "В", value: 11, caption: "Валет" },
  { key: "queen", label: "Queen", rank: "Д", value: 12, caption: "Дама" },
  { key: "king", label: "King", rank: "К", value: 13, caption: "Король" }
];

const faceHrefs = {
  wheat: {
    jack: "../faces/candidates/face-jack-poster-v5-palette.png",
    queen: "../faces/candidates/face-queen-poster-v5-palette.png",
    king: "../faces/candidates/face-king-poster-v5-palette.png"
  },
  sunflower: {
    jack: "../faces/candidates/face-jack-sunflower-poster-v2.png",
    queen: "../faces/candidates/face-queen-sunflower-poster-v1.png",
    king: "../faces/candidates/face-king-sunflower-poster-v1.png"
  },
  potato: {
    jack: "../faces/candidates/face-jack-potato-poster-v1.png",
    queen: "../faces/candidates/face-queen-potato-poster-v1.png",
    king: "../faces/candidates/face-king-potato-poster-v1.png"
  },
  beet: {
    jack: "../faces/candidates/face-jack-beet-poster-v1.png",
    queen: "../faces/candidates/face-queen-beet-poster-v1.png",
    king: "../faces/candidates/face-king-beet-poster-v1.png"
  }
};

function faceHref(suitId, rankKey) {
  return faceHrefs[suitId][rankKey];
}

const ordinaryCardDefinitions = suitDefinitions.flatMap(suit => [
  ...Array.from({ length: 10 }, (_, index) => ({
    id: `${suit.id}-${index + 1}`,
    suit: suit.id,
    rankKey: String(index + 1),
    label: `${index + 1} · ${suit.label}`,
    pickerLabel: String(index + 1),
    rank: index === 0 ? "Т" : String(index + 1),
    value: index + 1,
    kind: "number",
    suitHref: suit.pipHref
  })),
  ...faceRankDefinitions.map(face => ({
    id: `${suit.id}-${face.key}`,
    suit: suit.id,
    rankKey: face.key,
    label: `${face.label} · ${suit.label}`,
    pickerLabel: face.label,
    rank: face.rank,
    value: face.value,
    cornerValue: String(face.value),
    kind: "face",
    suitHref: suit.pipHref,
    faceHref: faceHref(suit.id, face.key),
    faceLabel: `${face.label} portrait`,
    faceCaption: face.caption
  }))
]);

const cardDefinitions = [
  ...ordinaryCardDefinitions,
  {
    id: "saboteur", suit: "all", rankKey: "saboteur", label: "Saboteur · S / 0", pickerLabel: "Saboteur", rank: "S", value: 0, cornerValue: "0", kind: "face",
    suitHref: "../pips/all-suits/suit-all-poster-v1.png",
    rankHref: "../ranks/saboteur/rank-saboteur-star-v1.png",
    rankAspectRatio: 1047 / 968,
    faceHref: "../faces/candidates/face-saboteur-poster-v2-palette-normalized.png",
    faceLabel: "Saboteur portrait",
    faceCaption: "Вредитель"
  }
];

const cardById = Object.fromEntries(cardDefinitions.map(card => [card.id, card]));
const clone = value => JSON.parse(JSON.stringify(value));
const cornerIds = [
  "topRank", "topValue", "topSuit", "bottomRank", "bottomValue", "bottomSuit",
  "topTrumpInset", "bottomTrumpInset"
];

const pipPositions = {
  1: [[.5, .5]],
  2: [[.5, .2], [.5, .8]],
  3: [[.5, .18], [.5, .5], [.5, .82]],
  4: [[.25, .22], [.75, .22], [.25, .78], [.75, .78]],
  5: [[.25, .2], [.75, .2], [.5, .5], [.25, .8], [.75, .8]],
  6: [[.25, .17], [.75, .17], [.25, .5], [.75, .5], [.25, .83], [.75, .83]],
  7: [[.25, .15], [.75, .15], [.5, .31], [.25, .5], [.75, .5], [.25, .85], [.75, .85]],
  8: [[.25, .14], [.75, .14], [.5, .3], [.25, .46], [.75, .46], [.5, .66], [.25, .86], [.75, .86]],
  9: [[.25, .13], [.75, .13], [.25, .37], [.75, .37], [.5, .5], [.25, .63], [.75, .63], [.25, .87], [.75, .87]],
  10: [[.25, .11], [.75, .11], [.5, .27], [.25, .39], [.75, .39], [.25, .61], [.75, .61], [.5, .73], [.25, .89], [.75, .89]]
};

function cornerDefaults(card) {
  const topRank = card.rankHref
    ? {
        type: "rankIcon", label: "Top rank icon", href: card.rankHref,
        x: 340, y: 430, visualHeight: 220, aspectRatio: card.rankAspectRatio, rotation: 0
      }
    : {
        type: "rank", label: "Top rank", text: card.rank,
        x: 340, y: 430, visualHeight: 220, rotation: 0
      };
  const bottomRank = card.rankHref
    ? {
        type: "rankIcon", label: "Bottom rank icon", href: card.rankHref,
        x: 1304, y: 1814, visualHeight: 220, aspectRatio: card.rankAspectRatio, rotation: 180
      }
    : {
        type: "rank", label: "Bottom rank", text: card.rank,
        x: 1304, y: 1814, visualHeight: 220, rotation: 180
      };
  return {
    topRank,
    topSuit: {
      type: "image", label: "Top corner pip", href: card.suitHref,
      x: 265, y: 510, width: 150, height: 150, rotation: 0
    },
    bottomRank,
    bottomSuit: {
      type: "image", label: "Bottom corner pip", href: card.suitHref,
      x: 1229, y: 1584, width: 150, height: 150, rotation: 180
    }
  };
}

function sevenDefaults(card) {
  const corners = cornerDefaults(card);
  return {
    topRank: corners.topRank,
    topSuit: corners.topSuit,
    pip1: { type: "image", label: "Pip 1 · upper left", href: card.suitHref, x: 470, y: 365, width: 340, height: 340, rotation: 0 },
    pip2: { type: "image", label: "Pip 2 · upper right", href: card.suitHref, x: 834, y: 365, width: 340, height: 340, rotation: 0 },
    pip3: { type: "image", label: "Pip 3 · upper center", href: card.suitHref, x: 652, y: 760, width: 340, height: 340, rotation: 0 },
    pip4: { type: "image", label: "Pip 4 · middle left", href: card.suitHref, x: 470, y: 1055, width: 340, height: 340, rotation: 0 },
    pip5: { type: "image", label: "Pip 5 · middle right", href: card.suitHref, x: 834, y: 1055, width: 340, height: 340, rotation: 0 },
    pip6: { type: "image", label: "Pip 6 · lower left", href: card.suitHref, x: 470, y: 1485, width: 340, height: 340, rotation: 180 },
    pip7: { type: "image", label: "Pip 7 · lower right", href: card.suitHref, x: 834, y: 1485, width: 340, height: 340, rotation: 180 },
    bottomRank: corners.bottomRank,
    bottomSuit: corners.bottomSuit
  };
}

function numberDefaults(card) {
  if (card.value === 7) return sevenDefaults(card);
  const corners = cornerDefaults(card);
  const size = card.value <= 3 ? 420 : card.value >= 9 ? 280 : 330;
  const pieces = { topRank: corners.topRank, topSuit: corners.topSuit };
  pipPositions[card.value].forEach(([nx, ny], index) => {
    const centerX = 458 + nx * 728;
    const centerY = 300 + ny * 1600;
    pieces[`pip${index + 1}`] = {
      type: "image", label: `Pip ${index + 1}`, href: card.suitHref,
      x: centerX - size / 2, y: centerY - size / 2,
      width: size, height: size, rotation: centerY > CARD.height / 2 ? 180 : 0
    };
  });
  pieces.bottomRank = corners.bottomRank;
  pieces.bottomSuit = corners.bottomSuit;
  return pieces;
}

function faceDefaults(card) {
  const corners = cornerDefaults(card);
  const face = { x: 372, y: 445, width: 900, height: 1350 };
  const facePieces = {
    topRank: corners.topRank,
    topValue: {
      type: "rank", textSource: "value", label: "Top numerical value", text: card.cornerValue,
      x: 490, y: 270, visualHeight: 90, rotation: 0
    },
    topSuit: corners.topSuit,
    centralFace: {
      type: "image", label: card.faceLabel, href: card.faceHref,
      ...face, contentBounds: card.faceContentBounds, rotation: 0
    },
    bottomRank: corners.bottomRank,
    bottomValue: {
      type: "rank", textSource: "value", label: "Bottom numerical value", text: card.cornerValue,
      x: 1154, y: 1974, visualHeight: 90, rotation: 180
    },
    bottomSuit: corners.bottomSuit
  };
  if (card.faceCaption) {
    facePieces.faceCaption = {
      type: "caption", label: "Face caption", text: card.faceCaption,
      x: CARD.width / 2, y: face.y + face.height + 90,
      visualHeight: 96, rotation: 0
    };
  }
  return facePieces;
}

function defaultsFor(cardId) {
  const card = cardById[cardId];
  return {
    ...(card.kind === "number" ? numberDefaults(card) : faceDefaults(card)),
    topTrumpInset: {
      type: "inset", label: "Top Trump inset artwork",
      x: 856, y: 116, width: 636, height: 636, rotation: 0
    },
    bottomTrumpInset: {
      type: "inset", label: "Bottom Trump inset artwork",
      x: 152, y: 1492, width: 636, height: 636, rotation: 0
    }
  };
}

let currentCardId = "wheat-7";
let currentSuitId = "wheat";
let currentInsetMode = "suit";
let layouts = {};
let pieces = defaultsFor(currentCardId);
let sharedCorners = null;
let selectedId = "topRank";
let drag = null;
let saveTimer = null;
let loadedStorageVersion = 0;
const fieldEditTimers = {};

const svg = document.querySelector("#card");
const piecesLayer = document.querySelector("#pieces");
const upperInsetArtwork = document.querySelector("#upperInsetArtwork");
const lowerInsetArtwork = document.querySelector("#lowerInsetArtwork");
const list = document.querySelector("#componentList");
const cardPicker = document.querySelector("#cardPicker");
const suitPicker = document.querySelector("#suitPicker");
const trumpInset = document.querySelector("#trumpInset");
const fields = {
  x: document.querySelector("#fieldX"), y: document.querySelector("#fieldY"),
  width: document.querySelector("#fieldWidth"), height: document.querySelector("#fieldHeight"),
  rotation: document.querySelector("#fieldRotation"), visualHeight: document.querySelector("#fieldFontSize")
};

function validPieceNumber(key, value) {
  return Number.isFinite(value) && (!["width", "height", "visualHeight"].includes(key) || value >= 20);
}

function mergeLayout(cardId, savedPieces) {
  const defaults = defaultsFor(cardId);
  for (const id of Object.keys(defaults)) {
    const currentDefault = defaultsFor(cardId)[id];
    if (savedPieces?.[id]) defaults[id] = { ...defaults[id], ...savedPieces[id] };
    if (loadedStorageVersion < 9 && id === "centralFace" && ["wheat-jack", "wheat-queen"].includes(cardId)) {
      defaults[id] = { ...defaults[id], ...currentDefault };
    }
    if (loadedStorageVersion < 10 && id === "centralFace" && cardId === "saboteur") {
      defaults[id].height = 1120;
    }
    if (loadedStorageVersion < 12 && id === "centralFace" && cardById[cardId].suit !== "all" && cardById[cardId].suit !== "wheat") {
      defaults[id] = { ...defaults[id], ...currentDefault };
    }
    defaults[id].type = currentDefault.type;
    defaults[id].label = currentDefault.label;
    // Asset and visible rank always follow the selected card, not stale saved data.
    if (defaults[id].type === "image") {
      defaults[id].href = currentDefault.href;
      defaults[id].contentBounds = currentDefault.contentBounds;
    }
    if (defaults[id].type === "rankIcon") {
      defaults[id].href = currentDefault.href;
      defaults[id].aspectRatio = currentDefault.aspectRatio;
    }
    if (defaults[id].type === "rank") {
      defaults[id].text = defaults[id].textSource === "value"
        ? cardById[cardId].cornerValue
        : cardById[cardId].rank;
    }
    if (defaults[id].type === "caption") defaults[id].text = cardById[cardId].faceCaption;
    for (const key of ["x", "y", "width", "height", "rotation", "visualHeight"]) {
      if (key in currentDefault && !validPieceNumber(key, defaults[id][key])) {
        defaults[id][key] = currentDefault[key];
      }
    }
    if (loadedStorageVersion < 16 && currentDefault.type === "inset") {
      defaults[id].height = defaults[id].width;
    }
  }
  return defaults;
}

function extractSharedCorners(source) {
  const shared = {};
  for (const id of cornerIds) {
    const piece = source?.[id];
    if (!piece) continue;
    shared[id] = { x: piece.x, y: piece.y };
    if (piece.type === "image" || piece.type === "inset") {
      shared[id].width = piece.width;
      shared[id].height = piece.height;
    } else if (isCenteredHeightPiece(piece)) {
      shared[id].visualHeight = piece.visualHeight;
    }
  }
  return shared;
}

function applySharedCorners(target) {
  if (!sharedCorners) return target;
  for (const id of cornerIds) {
    if (!target[id] || !sharedCorners[id]) continue;
    for (const [key, value] of Object.entries(sharedCorners[id])) {
      if (validPieceNumber(key, value)) target[id][key] = value;
    }
  }
  return target;
}

function captureSharedCorners() {
  sharedCorners = { ...sharedCorners, ...extractSharedCorners(pieces) };
}

function ensureSharedFaceValues() {
  const defaults = faceDefaults(cardById["wheat-jack"]);
  for (const id of ["topValue", "bottomValue"]) {
    if (!sharedCorners[id]) sharedCorners[id] = extractSharedCorners(defaults)[id];
  }
}

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    loadedStorageVersion = saved?.version || 1;
    document.querySelector("#mirrorCorners").checked = saved?.mirrorCorners !== false;
    if (saved?.layouts) {
      for (const [cardId, savedPieces] of Object.entries(saved.layouts)) {
        if (cardById[cardId]) layouts[cardId] = mergeLayout(cardId, savedPieces);
      }
      if (cardById[saved.currentCardId]) currentCardId = saved.currentCardId;
    } else if (saved?.pieces) {
      // Migrate the original single-card editor without losing the user's 7 layout.
      layouts["wheat-7"] = mergeLayout("wheat-7", saved.pieces);
    }
    sharedCorners = saved?.sharedCorners || extractSharedCorners(layouts["wheat-7"] || saved?.pieces || defaultsFor("wheat-7"));
    if (loadedStorageVersion < 16) {
      for (const id of ["topTrumpInset", "bottomTrumpInset"]) {
        if (validPieceNumber("width", sharedCorners?.[id]?.width)) {
          sharedCorners[id].height = sharedCorners[id].width;
        }
      }
    }
    if (suitDefinitions.some(suit => suit.id === saved?.currentSuitId)) currentSuitId = saved.currentSuitId;
    if (["suit", "trump"].includes(saved?.currentInsetMode)) currentInsetMode = saved.currentInsetMode;
  } catch (_) {}
  const loadedCard = cardById[currentCardId];
  if (loadedCard?.suit !== "all") currentSuitId = loadedCard.suit;
  if (!sharedCorners) sharedCorners = extractSharedCorners(defaultsFor("wheat-7"));
  ensureSharedFaceValues();
  pieces = applySharedCorners(clone(layouts[currentCardId] || defaultsFor(currentCardId)));
  syncPickers();
  mirrorCorners();
}

function rankFontFamily(text) {
  return text === "0" ? ZERO_FONT_FAMILY : CARD_FONT_FAMILY;
}

function isTextPiece(piece) {
  return piece.type === "rank" || piece.type === "caption";
}

function isCenteredHeightPiece(piece) {
  return isTextPiece(piece) || piece.type === "rankIcon";
}

function rankInkMetrics(text, size = RANK_METRIC_SIZE) {
  rankMetricContext.font = `700 ${size}px ${rankFontFamily(text)}`;
  rankMetricContext.textAlign = "center";
  rankMetricContext.textBaseline = "alphabetic";
  const metric = rankMetricContext.measureText(text);
  return {
    left: metric.actualBoundingBoxLeft,
    right: metric.actualBoundingBoxRight,
    ascent: metric.actualBoundingBoxAscent,
    descent: metric.actualBoundingBoxDescent
  };
}

function rankVisualTransform(piece, metric = rankInkMetrics(piece.text)) {
  const scale = piece.visualHeight / (metric.ascent + metric.descent);
  const inkCenterX = (metric.right - metric.left) / 2;
  const inkCenterY = (metric.descent - metric.ascent) / 2;
  return `translate(${piece.x} ${piece.y}) scale(${scale}) translate(${-inkCenterX} ${-inkCenterY})`;
}

function migrateRanksToVisibleBoxes() {
  if (loadedStorageVersion >= 5) return;
  const sevenRank = layouts["wheat-7"]?.topRank || defaultsFor("wheat-7").topRank;
  const oldFontSize = sevenRank.fontSize || 300;
  const metric = rankInkMetrics("7", oldFontSize);
  const visualHeight = metric.ascent + metric.descent;
  sharedCorners.topRank.visualHeight = visualHeight;
  sharedCorners.bottomRank.visualHeight = visualHeight;
  pieces = applySharedCorners(pieces);
}

function migrateFaceValuePlacement() {
  if (loadedStorageVersion >= 7) return;
  sharedCorners.topValue.x = 490;
  sharedCorners.bottomValue.x = CARD.width - 490;
  pieces = applySharedCorners(pieces);
}

function mirrorCorners() {
  if (!document.querySelector("#mirrorCorners").checked) return;
  const rank = pieces.topRank;
  const suit = pieces.topSuit;
  if (rank && pieces.bottomRank) {
    pieces.bottomRank = {
      ...pieces.bottomRank,
      x: CARD.width - rank.x, y: CARD.height - rank.y,
      visualHeight: rank.visualHeight, text: rank.text, rotation: 180
    };
  }
  const value = pieces.topValue;
  if (value && pieces.bottomValue) {
    pieces.bottomValue = {
      ...pieces.bottomValue,
      x: CARD.width - value.x, y: CARD.height - value.y,
      visualHeight: value.visualHeight, text: value.text, rotation: 180
    };
  }
  if (suit && pieces.bottomSuit) {
    pieces.bottomSuit = {
      ...pieces.bottomSuit,
      x: CARD.width - suit.x - suit.width, y: CARD.height - suit.y - suit.height,
      width: suit.width, height: suit.height, href: suit.href, rotation: 180
    };
  }
  const trumpInsetPiece = pieces.topTrumpInset;
  if (trumpInsetPiece && pieces.bottomTrumpInset) {
    pieces.bottomTrumpInset = {
      ...pieces.bottomTrumpInset,
      x: CARD.width - trumpInsetPiece.x - trumpInsetPiece.width,
      y: CARD.height - trumpInsetPiece.y - trumpInsetPiece.height,
      width: trumpInsetPiece.width,
      height: trumpInsetPiece.height,
      rotation: trumpInsetPiece.rotation
    };
  }
}

function rotationTransform(piece) {
  if (!piece.rotation) return "";
  if (isCenteredHeightPiece(piece)) return `rotate(${piece.rotation} ${piece.x} ${piece.y})`;
  return `rotate(${piece.rotation} ${piece.x + piece.width / 2} ${piece.y + piece.height / 2})`;
}

function makeSvg(tag, attrs = {}) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}

function imageSelectionBox(piece) {
  const bounds = piece.contentBounds;
  if (!bounds) return { x: piece.x, y: piece.y, width: piece.width, height: piece.height };
  const scale = Math.min(piece.width / bounds.sourceWidth, piece.height / bounds.sourceHeight);
  const fittedWidth = bounds.sourceWidth * scale;
  const fittedHeight = bounds.sourceHeight * scale;
  return {
    x: piece.x + (piece.width - fittedWidth) / 2 + bounds.x * scale,
    y: piece.y + (piece.height - fittedHeight) / 2 + bounds.y * scale,
    width: bounds.width * scale,
    height: bounds.height * scale
  };
}

function renderPieces() {
  mirrorCorners();
  captureSharedCorners();
  const card = cardById[currentCardId];
  const artworkSuit = card.suit === "all" ? "wheat" : card.suit;
  const artworkHref = currentInsetMode === "trump" ? trumpArtworkHref : artworkPlateHrefs[artworkSuit];
  const upperInset = upperInsetArtwork;
  const lowerInset = lowerInsetArtwork;
  upperInset.setAttribute("href", artworkHref);
  lowerInset.setAttribute("href", currentInsetMode === "trump" ? trumpArtworkRotatedHref : artworkHref);
  if (currentInsetMode === "trump") {
    const topTrumpInset = pieces.topTrumpInset;
    const bottomTrumpInset = pieces.bottomTrumpInset;
    for (const [inset, piece] of [[upperInset, topTrumpInset], [lowerInset, bottomTrumpInset]]) {
      inset.setAttribute("x", piece.x);
      inset.setAttribute("y", piece.y);
      inset.setAttribute("width", piece.width);
      inset.setAttribute("height", piece.height);
      const transform = rotationTransform(piece);
      if (transform) inset.setAttribute("transform", transform);
      else inset.removeAttribute("transform");
      inset.style.pointerEvents = "auto";
    }
  } else {
    upperInset.setAttribute("x", "0");
    upperInset.setAttribute("y", "0");
    upperInset.setAttribute("width", CARD.width);
    upperInset.setAttribute("height", CARD.height);
    upperInset.removeAttribute("transform");
    lowerInset.setAttribute("x", "58");
    lowerInset.setAttribute("y", "0");
    lowerInset.setAttribute("width", CARD.width);
    lowerInset.setAttribute("height", CARD.height);
    lowerInset.removeAttribute("transform");
    upperInset.style.pointerEvents = "none";
    lowerInset.style.pointerEvents = "none";
  }
  svg.setAttribute("aria-label", `Editable ${card.label} card`);
  piecesLayer.replaceChildren();
  for (const [id, piece] of Object.entries(pieces)) {
    if (piece.type === "inset" && currentInsetMode !== "trump") continue;
    const g = makeSvg("g", { class: `piece${id === selectedId ? " selected" : ""}`, "data-id": id, tabindex: "0" });
    const transform = rotationTransform(piece);
    if (transform) g.setAttribute("transform", transform);

    let visual;
    let selectionBox;
    if (piece.type === "inset") {
      selectionBox = imageSelectionBox(piece);
    } else if (isTextPiece(piece)) {
      const metric = rankInkMetrics(piece.text);
      const rawHeight = metric.ascent + metric.descent;
      const scale = piece.visualHeight / rawHeight;
      visual = makeSvg("text", {
        x: 0, y: 0, fill: "#263025", "text-anchor": "middle",
        "font-family": rankFontFamily(piece.text), "font-size": RANK_METRIC_SIZE, "font-weight": "700",
        transform: rankVisualTransform(piece, metric)
      });
      if (piece.text === "0") {
        visual.setAttribute("style", "font-feature-settings: 'zero' 1; font-variant-numeric: slashed-zero");
      }
      visual.textContent = piece.text;
      const visualWidth = (metric.left + metric.right) * scale;
      selectionBox = {
        x: piece.x - visualWidth / 2,
        y: piece.y - piece.visualHeight / 2,
        width: visualWidth,
        height: piece.visualHeight
      };
    } else if (piece.type === "rankIcon") {
      const width = piece.visualHeight * piece.aspectRatio;
      const x = piece.x - width / 2;
      const y = piece.y - piece.visualHeight / 2;
      visual = makeSvg("image", {
        href: piece.href, x, y, width, height: piece.visualHeight,
        draggable: "false", preserveAspectRatio: "xMidYMid meet"
      });
      selectionBox = { x, y, width, height: piece.visualHeight };
    } else {
      visual = makeSvg("image", {
        href: piece.href, x: piece.x, y: piece.y,
        width: piece.width, height: piece.height, draggable: "false",
        preserveAspectRatio: "xMidYMid meet"
      });
      selectionBox = imageSelectionBox(piece);
    }
    if (visual) g.append(visual);
    piecesLayer.append(g);

    g.append(makeSvg("rect", {
      class: "selection", x: selectionBox.x - 10, y: selectionBox.y - 10,
      width: selectionBox.width + 20, height: selectionBox.height + 20, rx: 8
    }));
    g.addEventListener("pointerdown", startDrag);
  }
  updatePanel();
  scheduleSave();
}

function buildSuitPicker() {
  suitPicker.replaceChildren();
  for (const suit of suitDefinitions) {
    const option = document.createElement("option");
    option.value = suit.id;
    option.textContent = suit.label;
    suitPicker.append(option);
  }
}

function buildCardPicker() {
  cardPicker.replaceChildren();
  const pickerCards = [
    ...ordinaryCardDefinitions.filter(card => card.suit === "wheat"),
    cardById.saboteur
  ];
  for (const card of pickerCards) {
    const option = document.createElement("option");
    option.value = card.rankKey;
    option.textContent = card.pickerLabel;
    cardPicker.append(option);
  }
}

function syncPickers() {
  const card = cardById[currentCardId];
  if (card.id === "saboteur") currentInsetMode = "trump";
  cardPicker.value = card.rankKey;
  suitPicker.value = currentSuitId;
  trumpInset.checked = currentInsetMode === "trump";
  suitPicker.disabled = card.suit === "all";
  trumpInset.disabled = card.id === "saboteur";
}

function buildList() {
  list.replaceChildren();
  for (const [id, piece] of Object.entries(pieces)) {
    if (piece.type === "inset" && currentInsetMode !== "trump") continue;
    const button = document.createElement("button");
    button.textContent = piece.label;
    button.dataset.id = id;
    button.addEventListener("click", () => select(id));
    list.append(button);
  }
}

function switchCard(cardId) {
  captureSharedCorners();
  layouts[currentCardId] = clone(pieces);
  currentCardId = cardId;
  if (cardById[cardId].suit !== "all") currentSuitId = cardById[cardId].suit;
  pieces = applySharedCorners(clone(layouts[cardId] || defaultsFor(cardId)));
  selectedId = "topRank";
  syncPickers();
  buildList();
  renderPieces();
}

function select(id) {
  selectedId = id;
  renderPieces();
}

function updatePanel() {
  const piece = pieces[selectedId];
  if (!piece) return;
  document.querySelector("#selectionTitle").textContent = piece.label;
  for (const key of ["x", "y", "width", "height", "rotation", "visualHeight"]) fields[key].value = piece[key] ?? "";
  document.querySelector("#widthLabel").hidden = isCenteredHeightPiece(piece);
  document.querySelector("#heightLabel").hidden = isCenteredHeightPiece(piece);
  document.querySelector("#fontLabel").hidden = !isCenteredHeightPiece(piece);
  for (const button of list.querySelectorAll("button")) button.classList.toggle("active", button.dataset.id === selectedId);
  document.querySelector("#readout").textContent = JSON.stringify({ [selectedId]: exportPiece(selectedId) }, null, 2);
}

function exportPiece(id) {
  const p = pieces[id];
  const result = { x: round(p.x), y: round(p.y) };
  if (isCenteredHeightPiece(p)) result.visualHeight = round(p.visualHeight);
  else { result.width = round(p.width); result.height = round(p.height); }
  result.rotation = round(p.rotation);
  return result;
}

function round(value) { return Math.round(value * 100) / 100; }

function clientToCard(event) {
  return new DOMPoint(event.clientX, event.clientY).matrixTransform(svg.getScreenCTM().inverse());
}

function startDrag(event) {
  event.preventDefault();
  const id = event.currentTarget.dataset.id;
  selectedId = id;
  const point = clientToCard(event);
  drag = { id, point, x: pieces[id].x, y: pieces[id].y };
  svg.setPointerCapture(event.pointerId);
  renderPieces();
}

function moveDrag(event) {
  if (!drag) return;
  const point = clientToCard(event);
  let x = drag.x + point.x - drag.point.x;
  let y = drag.y + point.y - drag.point.y;
  if (document.querySelector("#snapGrid").checked) { x = Math.round(x / 5) * 5; y = Math.round(y / 5) * 5; }
  setPosition(drag.id, x, y);
  renderPieces();
}

function endDrag() { drag = null; }

function setPosition(id, x, y) {
  const mirror = document.querySelector("#mirrorCorners").checked;
  if (mirror && id === "bottomRank") {
    pieces.topRank.x = CARD.width - x;
    pieces.topRank.y = CARD.height - y;
  } else if (mirror && id === "bottomValue") {
    pieces.topValue.x = CARD.width - x;
    pieces.topValue.y = CARD.height - y;
  } else if (mirror && id === "bottomSuit") {
    const top = pieces.topSuit;
    pieces.topSuit.x = CARD.width - x - top.width;
    pieces.topSuit.y = CARD.height - y - top.height;
  } else if (mirror && id === "bottomTrumpInset") {
    const top = pieces.topTrumpInset;
    pieces.topTrumpInset.x = CARD.width - x - top.width;
    pieces.topTrumpInset.y = CARD.height - y - top.height;
  } else {
    pieces[id].x = x;
    pieces[id].y = y;
  }
  mirrorCorners();
}

function editField(key, rawValue) {
  if (rawValue.trim() === "") {
    updatePanel();
    return;
  }
  const value = Number(rawValue);
  if (!validPieceNumber(key, value)) {
    updatePanel();
    return;
  }
  const piece = pieces[selectedId];
  if (key === "x" || key === "y") {
    setPosition(selectedId, key === "x" ? value : piece.x, key === "y" ? value : piece.y);
  } else if ((key === "width" || key === "height") && (piece.type === "image" || piece.type === "inset")) {
    const defaults = defaultsFor(currentCardId)[selectedId];
    const oldWidth = validPieceNumber("width", piece.width) ? piece.width : defaults.width;
    const oldHeight = validPieceNumber("height", piece.height) ? piece.height : defaults.height;
    piece[key] = value;
    if (document.querySelector("#lockAspect").checked) {
      const aspectRatio = oldWidth / oldHeight;
      if (key === "width") piece.height = value / aspectRatio;
      else piece.width = value * aspectRatio;
    }
  } else {
    piece[key] = value;
  }
  mirrorCorners();
  renderPieces();
}

function layoutPayload() {
  const card = cardById[currentCardId];
  const result = {
    canvas: CARD,
    card: { id: card.id, label: card.label, rank: card.rank, value: card.value },
    inset: {
      mode: currentInsetMode,
      artworkHref: currentInsetMode === "trump"
        ? trumpArtworkHref
        : artworkPlateHrefs[card.suit === "all" ? "wheat" : card.suit]
    },
    mirrorCorners: document.querySelector("#mirrorCorners").checked,
    pieces: {}
  };
  for (const id of Object.keys(pieces)) result.pieces[id] = exportPiece(id);
  return result;
}

function allLayoutsPayload() {
  captureSharedCorners();
  layouts[currentCardId] = clone(pieces);
  const exportedLayouts = {};
  for (const card of cardDefinitions) {
    const layout = applySharedCorners(
      clone(layouts[card.id] || defaultsFor(card.id))
    );
    exportedLayouts[card.id] = layout;
  }
  const fontTexts = new Set();
  for (const layout of Object.values(exportedLayouts)) {
    for (const piece of Object.values(layout)) {
      if (isTextPiece(piece)) fontTexts.add(piece.text);
    }
  }
  return {
    version: 16,
    canvas: CARD,
    fontMetrics: Object.fromEntries(
      [...fontTexts].map(text => [
        text,
        rankInkMetrics(text)
      ])
    ),
    currentCardId,
    currentSuitId,
    currentInsetMode,
    mirrorCorners: document.querySelector("#mirrorCorners").checked,
    sharedCorners,
    layouts: exportedLayouts
  };
}

function svgValues() {
  return Object.entries(pieces).map(([id, p]) => {
    if (isTextPiece(p)) {
      const font = p.text === "0" ? "Kolkhoz Bitter" : "Kolkhoz Podkova";
      const zeroFeature = p.text === "0" ? ` style="font-feature-settings: 'zero' 1; font-variant-numeric: slashed-zero"` : "";
      return `${id}: <g transform="${rotationTransform(p)}"><text x="0" y="0" text-anchor="middle" font-family="${font}" font-size="${RANK_METRIC_SIZE}" font-weight="700"${zeroFeature} transform="${rankVisualTransform(p)}">${p.text}</text></g>`;
    }
    if (p.type === "rankIcon") {
      const width = p.visualHeight * p.aspectRatio;
      return `${id}: <image href="${p.href}" x="${round(p.x - width / 2)}" y="${round(p.y - p.visualHeight / 2)}" width="${round(width)}" height="${round(p.visualHeight)}" transform="${rotationTransform(p)}"/>`;
    }
    return `${id}: <image href="${p.href}" x="${round(p.x)}" y="${round(p.y)}" width="${round(p.width)}" height="${round(p.height)}" transform="${rotationTransform(p)}"/>`;
  }).join("\n");
}

async function copy(text, button, successText) {
  await navigator.clipboard.writeText(text);
  const original = button.textContent;
  button.textContent = successText;
  setTimeout(() => button.textContent = original, 1200);
}

function scheduleSave() {
  clearTimeout(saveTimer);
  document.querySelector("#saveStatus").textContent = "Saving…";
  saveTimer = setTimeout(() => {
    captureSharedCorners();
    layouts[currentCardId] = clone(pieces);
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      version: 16,
      currentCardId,
      currentSuitId,
      currentInsetMode,
      layouts,
      sharedCorners,
      mirrorCorners: document.querySelector("#mirrorCorners").checked
    }));
    document.querySelector("#saveStatus").textContent = "Saved locally";
  }, 180);
}

svg.addEventListener("pointermove", moveDrag);
svg.addEventListener("pointerup", endDrag);
svg.addEventListener("pointercancel", endDrag);
upperInsetArtwork.dataset.id = "topTrumpInset";
lowerInsetArtwork.dataset.id = "bottomTrumpInset";
upperInsetArtwork.addEventListener("pointerdown", startDrag);
lowerInsetArtwork.addEventListener("pointerdown", startDrag);

for (const [key, input] of Object.entries(fields)) {
  input.addEventListener("input", () => {
    clearTimeout(fieldEditTimers[key]);
    if (input.value.trim() === "") return;
    fieldEditTimers[key] = setTimeout(() => editField(key, input.value), 400);
  });
  input.addEventListener("blur", () => {
    clearTimeout(fieldEditTimers[key]);
    editField(key, input.value);
  });
  input.addEventListener("keydown", event => {
    if (event.key !== "Enter") return;
    clearTimeout(fieldEditTimers[key]);
    editField(key, input.value);
    input.select();
  });
}
cardPicker.addEventListener("change", () => {
  const rankKey = cardPicker.value;
  switchCard(rankKey === "saboteur" ? "saboteur" : `${currentSuitId}-${rankKey}`);
});
suitPicker.addEventListener("change", () => {
  currentSuitId = suitPicker.value;
  const rankKey = cardById[currentCardId].rankKey;
  if (rankKey !== "saboteur") switchCard(`${currentSuitId}-${rankKey}`);
});
trumpInset.addEventListener("change", () => {
  currentInsetMode = trumpInset.checked ? "trump" : "suit";
  if (currentInsetMode !== "trump" && pieces[selectedId]?.type === "inset") selectedId = "topRank";
  buildList();
  renderPieces();
});
document.querySelector("#mirrorCorners").addEventListener("change", () => { mirrorCorners(); renderPieces(); });
document.querySelector("#toggleGuides").addEventListener("click", event => {
  svg.classList.toggle("guides-off");
  event.currentTarget.textContent = svg.classList.contains("guides-off") ? "Show guides" : "Hide guides";
});
document.querySelector("#zoomFit").addEventListener("click", () => svg.scrollIntoView({ block: "center", inline: "center" }));
document.querySelector("#resetSelected").addEventListener("click", () => {
  pieces[selectedId] = clone(defaultsFor(currentCardId)[selectedId]);
  mirrorCorners();
  renderPieces();
});
document.querySelector("#resetAll").addEventListener("click", () => {
  pieces = clone(defaultsFor(currentCardId));
  selectedId = "topRank";
  buildList();
  mirrorCorners();
  renderPieces();
});
document.querySelector("#copyJson").addEventListener("click", event => copy(JSON.stringify(layoutPayload(), null, 2), event.currentTarget, "Copied"));
document.querySelector("#copyAllJson").addEventListener("click", event => {
  const json = JSON.stringify(allLayoutsPayload(), null, 2);
  document.querySelector("#allLayoutExport").value = json;
  copy(json, event.currentTarget, "Copied");
});
document.querySelector("#copySvg").addEventListener("click", event => copy(svgValues(), event.currentTarget, "Copied"));
document.querySelector("#downloadJson").addEventListener("click", () => {
  const blob = new Blob([JSON.stringify(layoutPayload(), null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = `kolkhoz-${currentCardId}-layout.json`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 0);
});

window.addEventListener("keydown", event => {
  if (!selectedId || event.target.matches("input, select")) return;
  const delta = event.shiftKey ? 10 : 1;
  const changes = { ArrowLeft: [-delta, 0], ArrowRight: [delta, 0], ArrowUp: [0, -delta], ArrowDown: [0, delta] };
  if (!changes[event.key]) return;
  event.preventDefault();
  const [dx, dy] = changes[event.key];
  const p = pieces[selectedId];
  setPosition(selectedId, p.x + dx, p.y + dy);
  renderPieces();
});

async function initializeEditor() {
  buildSuitPicker();
  buildCardPicker();
  await document.fonts.ready;
  load();
  migrateRanksToVisibleBoxes();
  migrateFaceValuePlacement();
  buildList();
  renderPieces();
}

initializeEditor();
