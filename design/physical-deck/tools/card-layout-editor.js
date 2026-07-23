const CARD = { width: 1644, height: 2244 };
const STORAGE_KEY = "kolkhoz-card-layout-editor-v1";
const wheatPipHref = "../pips/wheat/suit-wheat-poster-c-v1.png";
const RANK_METRIC_SIZE = 1000;
const rankMetricCanvas = document.createElement("canvas");
const rankMetricContext = rankMetricCanvas.getContext("2d");

const cardDefinitions = [
  ...Array.from({ length: 10 }, (_, index) => ({
    id: `wheat-${index + 1}`,
    label: `${index + 1} · Wheat`,
    rank: String(index + 1),
    value: index + 1,
    kind: "number",
    suitHref: wheatPipHref
  })),
  {
    id: "wheat-jack", label: "Jack · Wheat", rank: "J", value: 11, cornerValue: "11", kind: "face",
    suitHref: wheatPipHref,
    faceHref: "../../../app/assets/art/field_plan/cards/faces/face-jack-wheat.png",
    faceLabel: "Jack portrait", faceSquare: true
  },
  {
    id: "wheat-queen", label: "Queen · Wheat", rank: "Q", value: 12, cornerValue: "12", kind: "face",
    suitHref: wheatPipHref,
    faceHref: "../../../app/assets/art/field_plan/cards/faces/face-queen-wheat.png",
    faceLabel: "Queen portrait", faceSquare: true
  },
  {
    id: "wheat-king", label: "King · Wheat", rank: "K", value: 13, cornerValue: "13", kind: "face",
    suitHref: wheatPipHref,
    faceHref: "../../../app/assets/ui/Cards/face-king-wheat.png",
    faceLabel: "King portrait"
  },
  {
    id: "saboteur", label: "Saboteur · S / 0", rank: "S", value: 0, cornerValue: "0", kind: "face",
    suitHref: "../../../app/assets/ui/Icons/icon-wrecker.png",
    faceHref: "../../../app/assets/ui/Cards/face-wrecker.png",
    faceLabel: "Saboteur portrait"
  }
];

const cardById = Object.fromEntries(cardDefinitions.map(card => [card.id, card]));
const clone = value => JSON.parse(JSON.stringify(value));
const cornerIds = ["topRank", "topValue", "topSuit", "bottomRank", "bottomValue", "bottomSuit"];

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
  return {
    topRank: {
      type: "rank", label: "Top rank", text: card.rank,
      x: 340, y: 430, visualHeight: 220, rotation: 0
    },
    topSuit: {
      type: "image", label: "Top corner pip", href: card.suitHref,
      x: 265, y: 510, width: 150, height: 150, rotation: 0
    },
    bottomRank: {
      type: "rank", label: "Bottom rank", text: card.rank,
      x: 1304, y: 1814, visualHeight: 220, rotation: 180
    },
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
  const face = card.faceSquare
    ? { x: 322, y: 620, width: 1000, height: 1000 }
    : { x: 372, y: 445, width: 900, height: 1350 };
  return {
    topRank: corners.topRank,
    topValue: {
      type: "rank", textSource: "value", label: "Top numerical value", text: card.cornerValue,
      x: 490, y: 270, visualHeight: 90, rotation: 0
    },
    topSuit: corners.topSuit,
    centralFace: {
      type: "image", label: card.faceLabel, href: card.faceHref,
      ...face, rotation: 0
    },
    bottomRank: corners.bottomRank,
    bottomValue: {
      type: "rank", textSource: "value", label: "Bottom numerical value", text: card.cornerValue,
      x: 1154, y: 1974, visualHeight: 90, rotation: 180
    },
    bottomSuit: corners.bottomSuit
  };
}

function defaultsFor(cardId) {
  const card = cardById[cardId];
  return card.kind === "number" ? numberDefaults(card) : faceDefaults(card);
}

let currentCardId = "wheat-7";
let layouts = {};
let pieces = defaultsFor(currentCardId);
let sharedCorners = null;
let selectedId = "topRank";
let drag = null;
let saveTimer = null;
let loadedStorageVersion = 0;

const svg = document.querySelector("#card");
const piecesLayer = document.querySelector("#pieces");
const list = document.querySelector("#componentList");
const cardPicker = document.querySelector("#cardPicker");
const fields = {
  x: document.querySelector("#fieldX"), y: document.querySelector("#fieldY"),
  width: document.querySelector("#fieldWidth"), height: document.querySelector("#fieldHeight"),
  rotation: document.querySelector("#fieldRotation"), visualHeight: document.querySelector("#fieldFontSize")
};

function mergeLayout(cardId, savedPieces) {
  const defaults = defaultsFor(cardId);
  for (const id of Object.keys(defaults)) {
    if (savedPieces?.[id]) defaults[id] = { ...defaults[id], ...savedPieces[id] };
    // Asset and visible rank always follow the selected card, not stale saved data.
    if (defaults[id].type === "image") defaults[id].href = defaultsFor(cardId)[id].href;
    if (defaults[id].type === "rank") {
      defaults[id].text = defaults[id].textSource === "value"
        ? cardById[cardId].cornerValue
        : cardById[cardId].rank;
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
    if (piece.type === "image") {
      shared[id].width = piece.width;
      shared[id].height = piece.height;
    } else if (piece.type === "rank") {
      shared[id].visualHeight = piece.visualHeight;
    }
  }
  return shared;
}

function applySharedCorners(target) {
  if (!sharedCorners) return target;
  for (const id of cornerIds) {
    if (target[id] && sharedCorners[id]) Object.assign(target[id], sharedCorners[id]);
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
  } catch (_) {}
  if (!sharedCorners) sharedCorners = extractSharedCorners(defaultsFor("wheat-7"));
  ensureSharedFaceValues();
  pieces = applySharedCorners(clone(layouts[currentCardId] || defaultsFor(currentCardId)));
  cardPicker.value = currentCardId;
  mirrorCorners();
}

function rankInkMetrics(text, size = RANK_METRIC_SIZE) {
  rankMetricContext.font = `700 ${size}px "Kolkhoz Zilla Slab", Georgia, serif`;
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
}

function rotationTransform(piece) {
  if (!piece.rotation) return "";
  if (piece.type === "rank") return `rotate(${piece.rotation} ${piece.x} ${piece.y})`;
  return `rotate(${piece.rotation} ${piece.x + piece.width / 2} ${piece.y + piece.height / 2})`;
}

function makeSvg(tag, attrs = {}) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}

function renderPieces() {
  mirrorCorners();
  captureSharedCorners();
  svg.setAttribute("aria-label", `Editable ${cardById[currentCardId].label} card`);
  piecesLayer.replaceChildren();
  for (const [id, piece] of Object.entries(pieces)) {
    const g = makeSvg("g", { class: `piece${id === selectedId ? " selected" : ""}`, "data-id": id, tabindex: "0" });
    const transform = rotationTransform(piece);
    if (transform) g.setAttribute("transform", transform);

    let visual;
    let selectionBox;
    if (piece.type === "rank") {
      const metric = rankInkMetrics(piece.text);
      const rawHeight = metric.ascent + metric.descent;
      const scale = piece.visualHeight / rawHeight;
      visual = makeSvg("text", {
        x: 0, y: 0, fill: "#263025", "text-anchor": "middle",
        "font-family": "Kolkhoz Zilla Slab, Georgia, serif", "font-size": RANK_METRIC_SIZE, "font-weight": "700",
        transform: rankVisualTransform(piece, metric)
      });
      visual.textContent = piece.text;
      const visualWidth = (metric.left + metric.right) * scale;
      selectionBox = {
        x: piece.x - visualWidth / 2,
        y: piece.y - piece.visualHeight / 2,
        width: visualWidth,
        height: piece.visualHeight
      };
    } else {
      visual = makeSvg("image", {
        href: piece.href, x: piece.x, y: piece.y,
        width: piece.width, height: piece.height, draggable: "false",
        preserveAspectRatio: "xMidYMid meet"
      });
      selectionBox = { x: piece.x, y: piece.y, width: piece.width, height: piece.height };
    }
    g.append(visual);
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

function buildCardPicker() {
  cardPicker.replaceChildren();
  for (const card of cardDefinitions) {
    const option = document.createElement("option");
    option.value = card.id;
    option.textContent = card.label;
    cardPicker.append(option);
  }
}

function buildList() {
  list.replaceChildren();
  for (const [id, piece] of Object.entries(pieces)) {
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
  pieces = applySharedCorners(clone(layouts[cardId] || defaultsFor(cardId)));
  selectedId = "topRank";
  cardPicker.value = cardId;
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
  document.querySelector("#widthLabel").hidden = piece.type === "rank";
  document.querySelector("#heightLabel").hidden = piece.type === "rank";
  document.querySelector("#fontLabel").hidden = piece.type !== "rank";
  for (const button of list.querySelectorAll("button")) button.classList.toggle("active", button.dataset.id === selectedId);
  document.querySelector("#readout").textContent = JSON.stringify({ [selectedId]: exportPiece(selectedId) }, null, 2);
}

function exportPiece(id) {
  const p = pieces[id];
  const result = { x: round(p.x), y: round(p.y) };
  if (p.type === "rank") result.visualHeight = round(p.visualHeight);
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
  } else {
    pieces[id].x = x;
    pieces[id].y = y;
  }
  mirrorCorners();
}

function editField(key, rawValue) {
  const value = Number(rawValue);
  if (!Number.isFinite(value)) return;
  const piece = pieces[selectedId];
  if (key === "x" || key === "y") {
    setPosition(selectedId, key === "x" ? value : piece.x, key === "y" ? value : piece.y);
  } else if ((key === "width" || key === "height") && piece.type === "image") {
    const oldWidth = piece.width, oldHeight = piece.height;
    piece[key] = value;
    if (document.querySelector("#lockAspect").checked) {
      if (key === "width") piece.height = value * oldHeight / oldWidth;
      else piece.width = value * oldWidth / oldHeight;
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
    mirrorCorners: document.querySelector("#mirrorCorners").checked,
    pieces: {}
  };
  for (const id of Object.keys(pieces)) result.pieces[id] = exportPiece(id);
  return result;
}

function svgValues() {
  return Object.entries(pieces).map(([id, p]) => {
    if (p.type === "rank") return `${id}: <g transform="${rotationTransform(p)}"><text x="0" y="0" text-anchor="middle" font-family="Kolkhoz Zilla Slab" font-size="${RANK_METRIC_SIZE}" font-weight="700" transform="${rankVisualTransform(p)}">${p.text}</text></g>`;
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
      version: 7,
      currentCardId,
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

for (const [key, input] of Object.entries(fields)) input.addEventListener("input", () => editField(key, input.value));
cardPicker.addEventListener("change", () => switchCard(cardPicker.value));
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
  buildCardPicker();
  await document.fonts.ready;
  load();
  migrateRanksToVisibleBoxes();
  migrateFaceValuePlacement();
  buildList();
  renderPieces();
}

initializeEditor();
