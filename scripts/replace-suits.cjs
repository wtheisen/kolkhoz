#!/usr/bin/env node
/**
 * Replace French card suits with crop suits in SVG files
 * Maps: Hearts -> Beet, Diamonds -> Potato, Clubs -> Sunflower, Spades -> Wheat
 *
 * Key: All paths must be SINGLE continuous closed paths (one M, ends with z)
 * Original heart: M 3.676,-9 C ... z (range: -8 to 8 horiz, -9 to 9 vert)
 */

const fs = require('fs');
const path = require('path');

// ============================================================================
// CROP SUIT PATHS - Matching the SuitIcon.jsx designs
// Converted from multi-element SVGs to compound paths
// ============================================================================

// WHEAT - Stem with grain ellipses on alternating sides (matches SuitIcon)
// Scaled to 65% for better fit on cards
const WHEAT_PATH = `
  M 0,-5.85 L 0,5.85
  M -1.95,-4.55 A 1.3,0.65 -30 1,1 -1.95,-3.25 A 1.3,0.65 -30 1,1 -1.95,-4.55 z
  M -2.28,-2.6 A 1.3,0.65 -25 1,1 -2.28,-1.3 A 1.3,0.65 -25 1,1 -2.28,-2.6 z
  M -1.95,-0.65 A 1.3,0.65 -20 1,1 -1.95,0.65 A 1.3,0.65 -20 1,1 -1.95,-0.65 z
  M 1.95,-4.55 A 1.3,0.65 30 1,1 1.95,-3.25 A 1.3,0.65 30 1,1 1.95,-4.55 z
  M 2.28,-2.6 A 1.3,0.65 25 1,1 2.28,-1.3 A 1.3,0.65 25 1,1 2.28,-2.6 z
  M 1.95,-0.65 A 1.3,0.65 20 1,1 1.95,0.65 A 1.3,0.65 20 1,1 1.95,-0.65 z
  M 0,-6.5 A 0.98,1.3 0 1,1 0,-3.9 A 0.98,1.3 0 1,1 0,-6.5 z`;

// SUNFLOWER - Center circle with 8 petal ellipses (matches SuitIcon)
// Scaled to 65% for better fit on cards
const SUNFLOWER_PATH = `
  M 0,-2.6 A 2.6,2.6 0 1,1 0,2.6 A 2.6,2.6 0 1,1 0,-2.6 z
  M 0,-7.15 A 0.98,1.63 0 1,1 0,-3.9 A 0.98,1.63 0 1,1 0,-7.15 z
  M 3.25,-6.18 A 0.98,1.63 45 1,1 4.55,-4.55 A 0.98,1.63 45 1,1 3.25,-6.18 z
  M 5.85,-1.3 A 1.63,0.98 0 1,1 5.85,1.3 A 1.63,0.98 0 1,1 5.85,-1.3 z
  M 3.25,4.55 A 0.98,1.63 -45 1,1 4.55,6.18 A 0.98,1.63 -45 1,1 3.25,4.55 z
  M 0,3.9 A 0.98,1.63 0 1,1 0,7.15 A 0.98,1.63 0 1,1 0,3.9 z
  M -4.55,4.55 A 0.98,1.63 45 1,1 -3.25,6.18 A 0.98,1.63 45 1,1 -4.55,4.55 z
  M -5.85,-1.3 A 1.63,0.98 0 1,1 -5.85,1.3 A 1.63,0.98 0 1,1 -5.85,-1.3 z
  M -4.55,-6.18 A 0.98,1.63 -45 1,1 -3.25,-4.55 A 0.98,1.63 -45 1,1 -4.55,-6.18 z`;

// POTATO - Round body with small eye circles (matches SuitIcon)
// Scaled to 65% for better fit on cards
const POTATO_PATH = `
  M 0,-5.85 C -3.9,-5.85 -5.85,-2.6 -5.85,0 C -5.85,3.25 -3.9,5.85 0,5.85 C 3.9,5.85 5.85,3.25 5.85,0 C 5.85,-2.6 3.9,-5.85 0,-5.85 z
  M -2.6,-1.95 A 0.65,0.65 0 1,1 -2.6,-0.65 A 0.65,0.65 0 1,1 -2.6,-1.95 z
  M 1.95,-0.65 A 0.52,0.52 0 1,1 1.95,0.39 A 0.52,0.52 0 1,1 1.95,-0.65 z
  M -1.3,1.95 A 0.59,0.59 0 1,1 -1.3,3.12 A 0.59,0.59 0 1,1 -1.3,1.95 z`;

// BEET - Bulbous body with 3 leaf sprouts (matches SuitIcon)
// Scaled to 65% for better fit on cards
const BEET_PATH = `
  M 0,-2.6 C -3.25,-2.6 -4.55,0 -3.9,2.6 C -3.25,4.55 -1.3,6.5 0,6.5 C 1.3,6.5 3.25,4.55 3.9,2.6 C 4.55,0 3.25,-2.6 0,-2.6 z
  M -1.3,-2.6 C -1.95,-4.55 -3.25,-5.85 -3.9,-6.5 C -2.6,-5.85 -1.3,-5.2 -0.65,-3.25 z
  M 0,-3.25 C 0,-5.2 0,-6.5 0,-7.15 C 0,-6.5 0,-5.2 0,-3.25 z
  M 1.3,-2.6 C 1.95,-4.55 3.25,-5.85 3.9,-6.5 C 2.6,-5.85 1.3,-5.2 0.65,-3.25 z`;

// Process a single card SVG file
function processCardSvg(inputPath) {
  const filename = path.basename(inputPath);

  let oldSuit = null;
  let newPath = null;

  if (filename.includes('hearts')) {
    oldSuit = 'hearts';
    newPath = BEET_PATH;
  } else if (filename.includes('diamonds')) {
    oldSuit = 'diamonds';
    newPath = POTATO_PATH;
  } else if (filename.includes('clubs')) {
    oldSuit = 'clubs';
    newPath = SUNFLOWER_PATH;
  } else if (filename.includes('spades')) {
    oldSuit = 'spades';
    newPath = WHEAT_PATH;
  } else {
    return false;
  }

  console.log(`Processing ${filename} (${oldSuit})`);

  let svg = fs.readFileSync(inputPath, 'utf8');
  let modified = false;

  if (oldSuit === 'hearts') {
    // Heart: d="M 3.676,-9 C 0.433,-9 ... z"
    const before = svg;
    svg = svg.replace(
      /d="M\s*3\.676\s*,\s*-9[^"]*z"/gi,
      `d="${newPath}"`
    );
    modified = svg !== before;
  }

  if (oldSuit === 'diamonds') {
    // Diamond: d="M 3.2433274,-4.7253274 ... z"
    const before = svg;
    svg = svg.replace(
      /d="M\s*3\.2433274\s*,\s*-4\.7253274[^"]*z"/gi,
      `d="${newPath}"`
    );
    modified = svg !== before;
  }

  if (oldSuit === 'clubs') {
    // Club paths start with "m [x],[y] c 0,0" and have characteristic bezier curves
    // Need to extract center coordinates and create sunflower at that position
    const clubPattern = /d="m\s*([\d.]+)\s*,\s*([\d.]+)\s+c\s+0\s*,\s*0[^"]*z"/gi;

    const before = svg;
    svg = svg.replace(clubPattern, (match, x, y) => {
      const cx = parseFloat(x);
      const cy = parseFloat(y);
      // Create sunflower centered at the club's position
      const sunflower = `
      M ${cx},${cy-2.6} A 2.6,2.6 0 1,1 ${cx},${cy+2.6} A 2.6,2.6 0 1,1 ${cx},${cy-2.6} z
      M ${cx},${cy-7.15} A 0.98,1.63 0 1,1 ${cx},${cy-3.9} A 0.98,1.63 0 1,1 ${cx},${cy-7.15} z
      M ${cx+3.25},${cy-6.18} A 0.98,1.63 45 1,1 ${cx+4.55},${cy-4.55} A 0.98,1.63 45 1,1 ${cx+3.25},${cy-6.18} z
      M ${cx+5.85},${cy-1.3} A 1.63,0.98 0 1,1 ${cx+5.85},${cy+1.3} A 1.63,0.98 0 1,1 ${cx+5.85},${cy-1.3} z
      M ${cx+3.25},${cy+4.55} A 0.98,1.63 -45 1,1 ${cx+4.55},${cy+6.18} A 0.98,1.63 -45 1,1 ${cx+3.25},${cy+4.55} z
      M ${cx},${cy+3.9} A 0.98,1.63 0 1,1 ${cx},${cy+7.15} A 0.98,1.63 0 1,1 ${cx},${cy+3.9} z
      M ${cx-4.55},${cy+4.55} A 0.98,1.63 45 1,1 ${cx-3.25},${cy+6.18} A 0.98,1.63 45 1,1 ${cx-4.55},${cy+4.55} z
      M ${cx-5.85},${cy-1.3} A 1.63,0.98 0 1,1 ${cx-5.85},${cy+1.3} A 1.63,0.98 0 1,1 ${cx-5.85},${cy-1.3} z
      M ${cx-4.55},${cy-6.18} A 0.98,1.63 -45 1,1 ${cx-3.25},${cy-4.55} A 0.98,1.63 -45 1,1 ${cx-4.55},${cy-6.18} z`;
      return `d="${sunflower}"`;
    });
    modified = svg !== before;
  }

  if (oldSuit === 'spades') {
    // Spade: d="M 7.989,3.103 ... z"
    const before = svg;
    svg = svg.replace(
      /d="M\s*7\.989\s*,\s*3\.103[^"]*z"/gi,
      `d="${newPath}"`
    );
    modified = svg !== before;
  }

  // Replace fonts with Oswald
  const beforeFont = svg;
  svg = svg.replace(/font-family:Arial/g, "font-family:'Oswald', sans-serif");
  svg = svg.replace(/font-family:Bitstream Vera Sans/g, "font-family:'Oswald', sans-serif");
  svg = svg.replace(/-inkscape-font-specification:Arial/g, "-inkscape-font-specification:'Oswald'");
  if (svg !== beforeFont) {
    modified = true;
  }

  if (modified) {
    fs.writeFileSync(inputPath, svg);
  }
  return modified;
}

function main() {
  const cardsDir = path.join(__dirname, '..', 'public', 'assets', 'cards');
  const files = fs.readdirSync(cardsDir).filter(f => f.endsWith('.svg'));

  let processed = 0;
  let skipped = 0;

  for (const file of files) {
    const inputPath = path.join(cardsDir, file);
    if (processCardSvg(inputPath)) {
      processed++;
    } else {
      skipped++;
    }
  }

  console.log(`\nDone! Modified ${processed} cards, skipped ${skipped} files.`);
}

main();
