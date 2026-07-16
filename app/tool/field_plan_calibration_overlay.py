#!/usr/bin/env python3

import argparse
import json
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "test/layout_goldens/field_plan_trick__phone_landscape_small.png"
OUTPUT = ROOT / "test/layout_goldens/field_plan_trick__calibration.png"
BACKGROUND = ROOT / "assets/art/field_plan/game/backgrounds/trick-field-light.png"
BRIGADE_PLOT_BACKGROUND = (
    ROOT / "assets/art/field_plan/game/backgrounds/brigade-plot-light.png"
)
FIELDS_BACKGROUND = ROOT / "assets/art/field_plan/game/backgrounds/fields-light.png"
CARD = ROOT / "assets/ui/Cards/card-template-light-no-overlay.png"
SIGN = ROOT / "assets/art/field_plan/shared/signs/field-sign.png"
SOURCE_GRID = ROOT / "test/layout_goldens/field_plan_trick__source_grid.png"

# Crop-edge quadrilaterals traced in the 1672 x 941 source background.
SOURCE_PARCELS = [
    [(370, 350), (590, 350), (430, 750), (205, 750)],
    [(610, 350), (850, 350), (840, 750), (500, 750)],
    [(900, 350), (1100, 350), (1280, 750), (900, 750)],
    [(1180, 350), (1360, 350), (1650, 750), (1320, 750)],
]

# The background fills the 1318 x 734 board rectangle at (8, 8) with BoxFit.cover.
BOARD_RECT = (8, 8, 1318, 734)

# Current Flutter homography destinations in rendered screenshot coordinates.
CARD_QUADS = [
    [(287, 323), (435, 323), (332, 572), (126, 572)],
    [(511, 323), (660, 323), (646, 572), (430, 572)],
    [(737, 323), (882, 323), (977, 572), (750, 572)],
    [(963, 323), (1112, 323), (1312, 572), (1077, 572)],
]

# Seat order follows the left-to-right screenshot order. These are the values currently
# in fieldPlanCardQuad; the browser tool uses them to recover each card's local slot.
SEAT_IDS = [1, 2, 3, 0]
NORMALIZED_QUADS = [
    [(0.492, 0.241), (1.162, 0.241), (0.696, 1.035), (-0.237, 1.035)],
    [(0.196, 0.241), (0.87, 0.241), (0.807, 1.035), (-0.171, 1.035)],
    [(-0.092, 0.241), (0.564, 0.241), (0.994, 1.035), (-0.033, 1.035)],
    [(-0.416, 0.241), (0.257, 0.241), (1.163, 1.035), (0.101, 1.035)],
]

# Rendered Flutter card-slot rectangles for the small landscape calibration golden.
# Keep these independent from CARD_QUADS so a newly calibrated destination does not
# change the coordinate space used to normalize its own points.
CARD_SLOT_RECTS = [
    {"x": 178.275, "y": 247.7157738095238, "width": 220.95, "height": 313.749},
    {"x": 467.775, "y": 247.7157738095238, "width": 220.95, "height": 313.749},
    {"x": 757.275, "y": 247.7157738095238, "width": 220.95, "height": 313.749},
    {"x": 1054.775, "y": 247.7157738095238, "width": 220.95, "height": 313.749},
]

# Current player-sign face rectangles in the small landscape calibration golden.
# The generated sign's posts extend below these face bounds.
SIGN_RECTS = [
    {"x": 305.868, "y": 211.318, "width": 141.026, "height": 58.72},
    {"x": 519.384, "y": 211.318, "width": 141.026, "height": 58.72},
    {"x": 727.628, "y": 211.318, "width": 141.026, "height": 58.72},
    {"x": 946.416, "y": 211.318, "width": 141.026, "height": 58.72},
]

# Initial brigade/plot placements are stored in plate pixels so the editor output
# remains stable across screen sizes and BoxFit.contain.
BRIGADE_PLOT_PORTRAIT_SOURCE_RECTS = [
    {"x": 569.265, "y": 203.661, "width": 72, "height": 72},
    {"x": 1030.802, "y": 203.617, "width": 72, "height": 72},
    {"x": 504.544, "y": 533.022, "width": 72, "height": 72},
    {"x": 1069.165, "y": 534.512, "width": 72, "height": 72},
]
BRIGADE_PLOT_NAME_SOURCE_RECTS = [
    {"x": 318.836, "y": 215.295, "width": 230, "height": 54},
    {"x": 1122.329, "y": 213.822, "width": 230, "height": 54},
    {"x": 253.68, "y": 545.943, "width": 230, "height": 54},
    {"x": 1157.069, "y": 544.904, "width": 230, "height": 54},
]
BRIGADE_PLOT_PLOT_CARD_SOURCE_RECTS = [
    {"x": 326.398, "y": 318.883, "width": 285.261, "height": 107.743},
    {"x": 1048.779, "y": 316.966, "width": 283.945, "height": 110.104},
    {"x": 125.212, "y": 680.503, "width": 420.386, "height": 132.93},
    {"x": 1114.203, "y": 680.186, "width": 410.42, "height": 132.839},
]
BRIGADE_PLOT_CELLAR_COUNT_SOURCE_RECTS = [
    {"x": 261.567, "y": 260.851, "width": 78, "height": 74},
    {"x": 1336.766, "y": 260.922, "width": 78, "height": 74},
    {"x": 73.864, "y": 614.497, "width": 78, "height": 74},
    {"x": 1512.349, "y": 614.142, "width": 78, "height": 74},
]
BRIGADE_PLOT_JOB_SIGN_SOURCE_RECTS = [
    {"x": 114.271, "y": 119.679, "width": 241.387, "height": 77.002},
    {"x": 503.565, "y": 118.321, "width": 240.269, "height": 75.608},
    {"x": 902.621, "y": 116.822, "width": 238.972, "height": 77.623},
    {"x": 1296.164, "y": 117.558, "width": 240.206, "height": 80.808},
]
BRIGADE_PLOT_CARD_SOURCE_RECTS = [
    {"x": 849.611, "y": 506.878, "width": 168.024, "height": 220.156},
    {"x": 849.735, "y": 272.802, "width": 166.586, "height": 218.905},
    {"x": 650.027, "y": 266.398, "width": 171.945, "height": 223.357},
    {"x": 649.113, "y": 503.384, "width": 170.118, "height": 223.927},
]
BRIGADE_PLOT_PLANNING_SOURCE_RECTS = [
    {"x": 700.635, "y": 340.152, "width": 267.274, "height": 288.654},
]

# Starting points for the fields / assignment editor. These are intentionally
# broad plate-pixel zones; the editor is the source of truth once calibrated.
FIELDS_JOB_SIGN_SOURCE_RECTS = [
    {"x": 235, "y": 135, "width": 240, "height": 78},
    {"x": 1197, "y": 135, "width": 240, "height": 78},
    {"x": 235, "y": 600, "width": 240, "height": 78},
    {"x": 1197, "y": 600, "width": 240, "height": 78},
]
FIELDS_JOB_PILE_SOURCE_RECTS = [
    {"x": 350, "y": 235, "width": 170, "height": 242},
    {"x": 1152, "y": 235, "width": 170, "height": 242},
    {"x": 350, "y": 655, "width": 170, "height": 242},
    {"x": 1152, "y": 655, "width": 170, "height": 242},
]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
    return ImageFont.truetype(path, size) if path.exists() else ImageFont.load_default()


def closed(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return [*points, points[0]]


def cover_point(point: tuple[int, int]) -> tuple[int, int]:
    left, top, width, height = BOARD_RECT
    scale = max(width / 1672, height / 941)
    drawn_width = 1672 * scale
    drawn_height = 941 * scale
    offset_x = left + (width - drawn_width) / 2
    offset_y = top + (height - drawn_height) / 2
    return (
        round(offset_x + point[0] * scale),
        round(offset_y + point[1] * scale),
    )


def rendered_parcels() -> list[list[tuple[int, int]]]:
    return [[cover_point(point) for point in parcel] for parcel in SOURCE_PARCELS]


def card_slot_rects() -> list[dict[str, float]]:
    return [dict(rect) for rect in CARD_SLOT_RECTS]


def generate_images() -> None:
    if not SOURCE.exists():
        raise SystemExit(
            f"Missing {SOURCE}. Run the field-plan screenshot golden test first."
        )

    image = Image.open(SOURCE).convert("RGBA")
    draw = ImageDraw.Draw(image, "RGBA")
    parcels = rendered_parcels()
    cyan = (0, 220, 255, 255)
    magenta = (255, 0, 210, 255)
    corner_fill = (255, 245, 210, 255)

    for index, (parcel, card) in enumerate(zip(parcels, CARD_QUADS), start=1):
        draw.line(closed(parcel), fill=cyan, width=5, joint="curve")
        draw.line(closed(card), fill=magenta, width=5, joint="curve")
        for corner_index, point in enumerate(parcel):
            x, y = point
            draw.ellipse(
                (x - 6, y - 6, x + 6, y + 6),
                fill=cyan,
                outline=corner_fill,
                width=2,
            )
            draw.text(
                (x + 8, y - 15),
                f"P{index}.{corner_index + 1}",
                fill=cyan,
                font=font(14),
            )
        for corner_index, point in enumerate(card):
            x, y = point
            draw.ellipse(
                (x - 6, y - 6, x + 6, y + 6),
                fill=magenta,
                outline=corner_fill,
                width=2,
            )
            draw.text(
                (x + 8, y + 3),
                f"C{index}.{corner_index + 1}",
                fill=magenta,
                font=font(14),
            )

    draw.rounded_rectangle(
        (145, 12, 650, 78),
        radius=8,
        fill=(242, 226, 185, 235),
        outline=(35, 35, 28, 255),
        width=2,
    )
    draw.line((165, 34, 225, 34), fill=cyan, width=5)
    draw.text((238, 21), "BACKGROUND PARCEL", fill=(25, 40, 42, 255), font=font(18))
    draw.line((165, 59, 225, 59), fill=magenta, width=5)
    draw.text((238, 46), "CURRENT CARD QUAD", fill=(45, 25, 40, 255), font=font(18))
    image.save(OUTPUT)
    print(OUTPUT)

    background = Image.open(BACKGROUND).convert("RGBA")
    grid = Image.new("RGBA", background.size, (255, 255, 255, 0))
    grid_draw = ImageDraw.Draw(grid, "RGBA")
    for x in range(0, background.width, 100):
        grid_draw.line((x, 0, x, background.height), fill=(0, 220, 255, 150), width=2)
        grid_draw.text((x + 5, 5), str(x), fill=(0, 70, 85, 255), font=font(18))
    for y in range(0, background.height, 100):
        grid_draw.line((0, y, background.width, y), fill=(255, 0, 210, 150), width=2)
        grid_draw.text((5, y + 5), str(y), fill=(100, 0, 80, 255), font=font(18))
    Image.alpha_composite(background, grid).save(SOURCE_GRID)
    print(SOURCE_GRID)


HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Field Plan Layout Editor</title>
<style>
  :root { color-scheme: dark; --ink:#f2e7c7; --paper:#24251f; --panel:#303228; --red:#b94835; --cyan:#00dcff; --pink:#ff36d7; --green:#77d08b; }
  * { box-sizing:border-box; }
  body { margin:0; min-height:100vh; background:#181a16; color:var(--ink); font:15px/1.35 system-ui,sans-serif; }
  header { display:flex; align-items:baseline; gap:18px; padding:13px 18px; border-bottom:1px solid #555744; background:#20221c; }
  h1 { margin:0; font-size:18px; letter-spacing:.04em; text-transform:uppercase; }
  header span { color:#aaa88f; }
  main { display:grid; grid-template-columns:minmax(500px,1fr) 330px; gap:14px; padding:14px; }
  .stage { min-width:0; }
  .canvas-wrap { position:relative; width:100%; background:#0d0e0c; border:1px solid #555744; box-shadow:0 8px 28px #0008; }
  canvas { display:block; width:100%; height:auto; touch-action:none; cursor:crosshair; }
  aside { display:flex; flex-direction:column; gap:12px; }
  section { padding:12px; background:var(--panel); border:1px solid #555744; }
  h2 { margin:0 0 9px; font-size:13px; text-transform:uppercase; letter-spacing:.08em; color:#d0c397; }
  label { display:flex; justify-content:space-between; gap:10px; margin:7px 0; color:#d5cfb9; }
  select,button,textarea { color:var(--ink); background:#1b1d18; border:1px solid #666852; border-radius:3px; font:inherit; }
  select,button { padding:7px 9px; }
  button { cursor:pointer; }
  button:hover { border-color:#b5aa82; background:#292c23; }
  button.primary { background:#7e2e24; border-color:#c85b45; }
  .cards { display:grid; grid-template-columns:repeat(4,1fr); gap:6px; }
  .cards button.active { background:#8e284f; border-color:#ff76dc; }
  .screens { display:grid; grid-template-columns:1fr 1fr; gap:6px; margin-bottom:10px; }
  .screens button.active { background:#654021; border-color:#e6b66e; }
  .mode { display:grid; grid-template-columns:repeat(3,1fr); gap:6px; margin:8px 0; }
  .mode button.active { background:#315e3b; border-color:var(--green); }
  [hidden] { display:none !important; }
  .row { display:flex; flex-wrap:wrap; gap:7px; margin-top:8px; }
  .row button { flex:1; min-width:85px; }
  .checks label { justify-content:flex-start; }
  textarea { width:100%; min-height:245px; resize:vertical; padding:9px; font:12px/1.4 ui-monospace,SFMono-Regular,monospace; white-space:pre; }
  .help { color:#bcb9a5; font-size:13px; }
  .legend { display:flex; flex-wrap:wrap; gap:14px; margin:10px 2px 0; color:#c7c2ad; font-size:13px; }
  .swatch { display:inline-block; width:20px; height:3px; margin:0 6px 3px 0; vertical-align:middle; }
  #status { min-height:20px; margin-top:7px; color:#86d19b; font-size:13px; }
  @media(max-width:900px) { main { grid-template-columns:1fr; } aside { display:grid; grid-template-columns:1fr 1fr; } .output { grid-column:1/-1; } }
</style>
</head>
<body>
<header><h1 id="page-title">Brigade / Plot Layout Editor</h1><span id="page-subtitle">Position Flutter overlays against the farmstead plate.</span></header>
<main>
  <div class="stage">
    <div class="canvas-wrap"><canvas id="canvas" width="1334" height="750"></canvas></div>
    <div class="legend">
      <span data-screen="farmstead"><i class="swatch" style="background:var(--cyan)"></i>portraits</span>
      <span data-screen="farmstead"><i class="swatch" style="background:var(--green)"></i>names</span>
      <span data-screen="farmstead"><i class="swatch" style="background:var(--pink)"></i>plot cards</span>
      <span data-screen="farmstead"><i class="swatch" style="background:#f3a444"></i>cellar counts</span>
      <span data-screen="farmstead"><i class="swatch" style="background:#c6f36b"></i>job signs</span>
      <span data-screen="farmstead"><i class="swatch" style="background:#ff36d7"></i>trick cards</span>
      <span data-screen="fields" hidden><i class="swatch" style="background:var(--pink)"></i>job piles</span>
      <span data-screen="fields" hidden><i class="swatch" style="background:#c6f36b"></i>job signs</span>
      <span><i class="swatch" style="background:#f7e36d"></i>selected element</span>
    </div>
  </div>
  <aside>
    <section>
      <div class="screens" id="screens">
        <button id="screen-farmstead" class="active">Farmstead</button>
        <button id="screen-fields">Fields / assignment</button>
      </div>
      <h2 id="item-heading">Seat</h2>
      <div class="cards" id="card-buttons"></div>
      <div class="mode" id="modes">
        <button id="edit-portraits" class="active">Portraits</button><button id="edit-names">Names</button><button id="edit-plotCards">Plot cards</button>
        <button id="edit-cellarCounts">Cellar count</button><button id="edit-jobSigns">Job signs</button><button id="edit-crossroads">Trick cards</button><button id="edit-planning">Planning</button>
        <button id="edit-fieldJobPiles" hidden>Job piles</button><button id="edit-fieldJobSigns" hidden>Job signs</button>
      </div>
      <div class="checks">
        <label><input id="show-preview" type="checkbox" checked> Show artwork previews</label>
        <label><input id="skew-mode" type="checkbox"> Skew corners independently</label>
      </div>
      <div class="row"><button id="reset">Reset selected</button><button id="reset-all">Reset group</button></div>
      <div class="row"><button id="download">Download JSON</button></div>
      <div id="status"></div>
    </section>
    <section>
      <h2>Controls</h2>
      <div class="help">Choose a screen and element group, then drag a corner handle to resize or drag inside an object to move it. Enable skew mode to pull each corner independently and emulate an element lying flat. Corresponding edges across elements and opposite edges within one element glow when their angles are within 1.5°. Job-sign zones mark the widget face; the real sign art uses the same width-driven aspect ratio as Flutter, so its posts extend to the rendered position. Arrow keys nudge the selected corner by one pixel; hold Shift for ten. Each screen is retained independently in this browser.</div>
    </section>
    <section class="output">
      <h2>Flutter output</h2>
      <textarea id="output" readonly spellcheck="false"></textarea>
      <div class="row"><button class="primary" id="copy">Copy Dart</button></div>
    </section>
  </aside>
</main>
<script>
const canvas=document.querySelector('#canvas'), ctx=canvas.getContext('2d');
const state={config:null,screen:'farmstead',plotRects:{portraits:[],names:[],plotCards:[],cellarCounts:[],jobSigns:[],crossroads:[],planning:[]},plotQuads:{portraits:[],names:[],plotCards:[],cellarCounts:[],jobSigns:[],crossroads:[],planning:[]},fieldRects:{fieldJobPiles:[],fieldJobSigns:[]},fieldQuads:{fieldJobPiles:[],fieldJobSigns:[]},mode:'portraits',active:0,handle:null,drag:null,images:{},preview:null,alignment:[],angleMatches:[],sizeMatch:null,animationFrame:null};
const $=s=>document.querySelector(s);
const clone=v=>JSON.parse(JSON.stringify(v));
const names=['TL','TR','BR','BL'];
const alignmentThreshold=3;
const angleMatchThreshold=1.5;
const cardStorageKey='field-plan-card-quads-v3';
const signStorageKey='field-plan-sign-rects-v2';
const plotStorageKey='field-plan-brigade-plot-rects-v2';
const plotQuadStorageKey='field-plan-brigade-plot-quads-v1';
const fieldStorageKey='field-plan-fields-assignment-rects-v2';
const fieldQuadStorageKey='field-plan-fields-assignment-quads-v2';
const containMigrationKey='field-plan-brigade-plot-contain-migration-v1';
const signAssetAspectRatio=1413/846;
function loadImage(src){return new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=reject;img.src=src;});}
function imagePoint(event){const r=canvas.getBoundingClientRect();return{x:(event.clientX-r.left)*canvas.width/r.width,y:(event.clientY-r.top)*canvas.height/r.height};}
function pointInQuad(p,q){let sign=0;for(let i=0;i<4;i++){const a=q[i],b=q[(i+1)%4],cross=(b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x);if(Math.abs(cross)<.01)continue;const s=Math.sign(cross);if(sign&&s!==sign)return false;sign=s;}return true;}
function rectCorners(r){return[{x:r.x,y:r.y},{x:r.x+r.width,y:r.y},{x:r.x+r.width,y:r.y+r.height},{x:r.x,y:r.y+r.height}];}
function pointInRect(p,r){return p.x>=r.x&&p.x<=r.x+r.width&&p.y>=r.y&&p.y<=r.y+r.height;}
function resizedRect(original,handle,p){
  const right=original.x+original.width,bottom=original.y+original.height,minWidth=48,minHeight=28;
  let left=original.x,top=original.y,newRight=right,newBottom=bottom;
  if(handle===0||handle===3)left=Math.min(p.x,right-minWidth);else newRight=Math.max(p.x,original.x+minWidth);
  if(handle===0||handle===1)top=Math.min(p.y,bottom-minHeight);else newBottom=Math.max(p.y,original.y+minHeight);
  return{x:left,y:top,width:newRight-left,height:newBottom-top};
}
function project(q,u,v){
  const p0=q[0],p1=q[1],p2=q[2],p3=q[3];
  const dx1=p1.x-p2.x,dx2=p3.x-p2.x,dx3=p0.x-p1.x+p2.x-p3.x;
  const dy1=p1.y-p2.y,dy2=p3.y-p2.y,dy3=p0.y-p1.y+p2.y-p3.y;
  const det=dx1*dy2-dx2*dy1;
  const gx=(dx3*dy2-dx2*dy3)/det,gy=(dx1*dy3-dx3*dy1)/det;
  const a=p1.x-p0.x+gx*p1.x,b=p3.x-p0.x+gy*p3.x,c=p0.x;
  const d=p1.y-p0.y+gx*p1.y,e=p3.y-p0.y+gy*p3.y,f=p0.y;
  const z=gx*u+gy*v+1;
  return{x:(a*u+b*v+c)/z,y:(d*u+e*v+f)/z};
}
function affineTriangle(img,s,d){
  const [s0,s1,s2]=s,[d0,d1,d2]=d;
  const den=s0.x*(s1.y-s2.y)+s1.x*(s2.y-s0.y)+s2.x*(s0.y-s1.y);
  const a=(d0.x*(s1.y-s2.y)+d1.x*(s2.y-s0.y)+d2.x*(s0.y-s1.y))/den;
  const c=(d0.x*(s2.x-s1.x)+d1.x*(s0.x-s2.x)+d2.x*(s1.x-s0.x))/den;
  const e=(d0.x*(s1.x*s2.y-s2.x*s1.y)+d1.x*(s2.x*s0.y-s0.x*s2.y)+d2.x*(s0.x*s1.y-s1.x*s0.y))/den;
  const b=(d0.y*(s1.y-s2.y)+d1.y*(s2.y-s0.y)+d2.y*(s0.y-s1.y))/den;
  const dd=(d0.y*(s2.x-s1.x)+d1.y*(s0.x-s2.x)+d2.y*(s1.x-s0.x))/den;
  const f=(d0.y*(s1.x*s2.y-s2.x*s1.y)+d1.y*(s2.x*s0.y-s0.x*s2.y)+d2.y*(s0.x*s1.y-s1.x*s0.y))/den;
  ctx.save();ctx.beginPath();ctx.moveTo(d0.x,d0.y);ctx.lineTo(d1.x,d1.y);ctx.lineTo(d2.x,d2.y);ctx.closePath();ctx.clip();ctx.transform(a,b,c,dd,e,f);ctx.drawImage(img,0,0);ctx.restore();
}
function drawWarp(img,q){
  const cols=10,rows=14,w=img.width,h=img.height;
  for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){
    const u0=x/cols,u1=(x+1)/cols,v0=y/rows,v1=(y+1)/rows;
    const s00={x:u0*w,y:v0*h},s10={x:u1*w,y:v0*h},s11={x:u1*w,y:v1*h},s01={x:u0*w,y:v1*h};
    const d00=project(q,u0,v0),d10=project(q,u1,v0),d11=project(q,u1,v1),d01=project(q,u0,v1);
    affineTriangle(img,[s00,s10,s11],[d00,d10,d11]);affineTriangle(img,[s00,s11,s01],[d00,d11,d01]);
  }
}
function quadBounds(q){const xs=q.map(p=>p.x),ys=q.map(p=>p.y),left=Math.min(...xs),top=Math.min(...ys),right=Math.max(...xs),bottom=Math.max(...ys);return{x:left,y:top,width:right-left,height:bottom-top};}
function signImageQuad(q){
  const topWidth=Math.hypot(q[1].x-q[0].x,q[1].y-q[0].y),bottomWidth=Math.hypot(q[2].x-q[3].x,q[2].y-q[3].y),leftHeight=Math.hypot(q[3].x-q[0].x,q[3].y-q[0].y),rightHeight=Math.hypot(q[2].x-q[1].x,q[2].y-q[1].y);
  const scale=((topWidth+bottomWidth)/2/signAssetAspectRatio)/Math.max(1,(leftHeight+rightHeight)/2);
  return [q[0],q[1],{x:q[1].x+(q[2].x-q[1].x)*scale,y:q[1].y+(q[2].y-q[1].y)*scale},{x:q[0].x+(q[3].x-q[0].x)*scale,y:q[0].y+(q[3].y-q[0].y)*scale}];
}
function drawSign(q){
  drawWarp(state.images.sign,signImageQuad(q));
}
function makePreview(){
  const c=document.createElement('canvas');c.width=350;c.height=490;const x=c.getContext('2d');
  x.fillStyle='#e8d9ad';x.fillRect(0,0,c.width,c.height);x.strokeStyle='#34372d';x.lineWidth=10;x.strokeRect(5,5,c.width-10,c.height-10);
  x.strokeStyle='#a33a28';x.lineWidth=4;x.strokeRect(23,23,c.width-46,c.height-46);
  x.fillStyle='#4f6343';x.fillRect(42,72,c.width-84,c.height-144);
  x.strokeStyle='#d8c68f';x.lineWidth=3;for(let i=0;i<7;i++){x.beginPath();x.moveTo(42,95+i*44);x.lineTo(c.width-42,95+i*44);x.stroke();}
  x.fillStyle='#efe0b8';x.font='bold 42px system-ui';x.textAlign='center';x.fillText('CARD',c.width/2,285);
  x.font='bold 24px system-ui';x.fillText('FIELD PLAN',c.width/2,327);return c;
}
function drawBase(){
  ctx.clearRect(0,0,canvas.width,canvas.height);
  const [left,top,width,height]=state.config.boardRect,img=state.screen==='fields'?state.images.fieldsBackground:state.images.plotBackground;
  const scale=Math.min(width/img.width,height/img.height),dw=img.width*scale,dh=img.height*scale;
  ctx.drawImage(img,left+(width-dw)/2,top+(height-dh)/2,dw,dh);
}
function polygon(q,color,width=4){ctx.beginPath();ctx.moveTo(q[0].x,q[0].y);for(let i=1;i<4;i++)ctx.lineTo(q[i].x,q[i].y);ctx.closePath();ctx.strokeStyle=color;ctx.lineWidth=width;ctx.stroke();}
function alignedPoint(pointIndex){
  const row=pointIndex<2?'TOPS':'BOTTOMS',indices=pointIndex<2?[0,1]:[2,3];
  const source=state.quads[state.active][pointIndex],matches=[];
  state.quads.forEach((quad,cardIndex)=>indices.forEach(index=>{
    if(cardIndex===state.active&&index===pointIndex)return;
    const point=quad[index];
    if(Math.abs(point.y-source.y)<=alignmentThreshold)matches.push(point);
  }));
  if(!matches.length)return null;
  const y=(source.y+matches.reduce((sum,point)=>sum+point.y,0))/(matches.length+1);
  return{y,row,count:matches.length+1,until:Date.now()+520};
}
function alignedSignEdge(edge){
  const rects=activeRects(),source=rects[state.active],sourceY=edge==='top'?source.y:source.y+source.height,matches=[];
  rects.forEach((rect,index)=>{if(index===state.active)return;const y=edge==='top'?rect.y:rect.y+rect.height;if(Math.abs(y-sourceY)<=alignmentThreshold)matches.push(y);});
  if(!matches.length)return null;
  const y=(sourceY+matches.reduce((sum,value)=>sum+value,0))/(matches.length+1);
  return{y,row:`${state.mode.toUpperCase()} ${edge.toUpperCase()}S`,count:matches.length+1,until:Date.now()+520};
}
function matchingSignSize(){
  if($('#skew-mode').checked||state.mode==='cards'||state.handle==null||state.drag?.kind==='rect')return null;
  const rects=activeRects(),source=rects[state.active],matches=[];
  rects.forEach((rect,index)=>{if(index!==state.active&&Math.abs(rect.width-source.width)<=alignmentThreshold&&Math.abs(rect.height-source.height)<=alignmentThreshold)matches.push(index);});
  return matches.length?{indices:[state.active,...matches],width:source.width,height:source.height,until:Date.now()+520}:null;
}
const quadEdges=[{name:'TOP',points:[0,1]},{name:'RIGHT',points:[1,2]},{name:'BOTTOM',points:[3,2]},{name:'LEFT',points:[0,3]}];
function edgeAngle(q,edge){const [a,b]=quadEdges[edge].points,dx=q[b].x-q[a].x,dy=q[b].y-q[a].y;let angle=Math.atan2(dy,dx)*180/Math.PI;while(angle>90)angle-=180;while(angle<=-90)angle+=180;return angle;}
function angleDifference(a,b){let delta=Math.abs(a-b)%180;return delta>90?180-delta:delta;}
function relevantAngleEdges(){if(state.drag?.kind==='quad'||state.handle==null)return [0,1,2,3];return [[0,3],[0,1],[1,2],[2,3]][state.handle];}
function matchingGroupAngles(){
  const quads=activeQuads(),source=quads[state.active];if(!source)return [];
  return relevantAngleEdges().map(edge=>{const angle=edgeAngle(source,edge),indices=[];quads.forEach((quad,index)=>{if(index!==state.active&&angleDifference(angle,edgeAngle(quad,edge))<=angleMatchThreshold)indices.push(index);});return indices.length?{kind:'group',edge,angle,indices:[state.active,...indices],until:Date.now()+520}:null;}).filter(Boolean);
}
function matchingInternalAngles(){
  const source=activeQuads()[state.active];if(!source)return [];
  const opposite=[2,3,0,1],seen=new Set(),matches=[];
  relevantAngleEdges().forEach(edge=>{const other=opposite[edge],key=[edge,other].sort().join('-');if(seen.has(key))return;seen.add(key);const delta=angleDifference(edgeAngle(source,edge),edgeAngle(source,other));if(delta<=angleMatchThreshold)matches.push({kind:'internal',edges:[edge,other],delta,until:Date.now()+520});});return matches;
}
function updateAlignment(){
  if($('#skew-mode').checked){state.alignment=[];state.sizeMatch=null;state.angleMatches=[...matchingGroupAngles(),...matchingInternalAngles()];return;}
  state.angleMatches=[];
  if(state.mode==='cards'){
    const guide=state.drag?.kind==='quad'?(alignedPoint(0)||alignedPoint(2)):state.handle!=null?alignedPoint(state.handle):null;
    state.alignment=guide?[guide]:[];state.sizeMatch=null;return;
  }
  const edges=state.drag?.kind==='sign'||state.handle==null?['top','bottom']:(state.handle<2?['top']:['bottom']);
  state.alignment=edges.map(alignedSignEdge).filter(Boolean);state.sizeMatch=matchingSignSize();
}
function currentRects(){return state.screen==='fields'?state.fieldRects:state.plotRects;}
function currentQuads(){return state.screen==='fields'?state.fieldQuads:state.plotQuads;}
function activeRects(){return state.mode==='signs'?state.signRects:currentRects()[state.mode]||[];}
function activeQuads(){return currentQuads()[state.mode]||[];}
function itemLabel(mode,index){
  if(mode==='jobSigns')return ['Wheat','Sunflower','Potato','Beet'][index]||`Job ${index+1}`;
  if(mode==='planning')return 'Planning panel';
  if(['portraits','names','plotCards','cellarCounts','crossroads'].includes(mode))return ['Other Player 1','Other Player 2','Other Player 3','You'][index]||`Player ${index+1}`;
  if(['fieldJobPiles','fieldJobSigns'].includes(mode))return ['Wheat','Sunflower','Potato','Beet'][index]||`Job ${index+1}`;
  return `Seat ${state.config.seatIds[index]}`;
}
function drawRectGroup(rects,mode,color,label){
  const quads=currentQuads()[mode];
  rects.forEach((r,i)=>{const active=state.mode===mode&&i===state.active,stroke=active?'#f7e36d':color,corners=quads[i]||rectCorners(r),bounds=quadBounds(corners);ctx.save();ctx.beginPath();ctx.moveTo(corners[0].x,corners[0].y);corners.slice(1).forEach(p=>ctx.lineTo(p.x,p.y));ctx.closePath();ctx.fillStyle=color+'28';ctx.fill();ctx.strokeStyle=stroke;ctx.lineWidth=active?5:2;ctx.stroke();ctx.fillStyle=stroke;ctx.font='bold 14px system-ui';ctx.textAlign='left';ctx.textBaseline='top';ctx.fillText(`${label} · ${itemLabel(mode,i)}`,bounds.x+8,bounds.y+8);if(active)corners.forEach((p,j)=>{ctx.fillStyle=stroke;ctx.fillRect(p.x-9,p.y-9,18,18);ctx.strokeStyle='#241d19';ctx.lineWidth=2;ctx.strokeRect(p.x-9,p.y-9,18,18);ctx.fillStyle='#211f18';ctx.font='bold 10px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(names[j][0],p.x,p.y+.5);});ctx.restore();});
}
function drawAlignment(){
  state.alignment=state.alignment.filter(guide=>Date.now()<=guide.until);
  if(!state.alignment.length)return;
  const pulse=.55+.45*Math.sin(Date.now()/42);
  ctx.save();
  state.alignment.forEach(guide=>{
    const life=Math.max(0,(guide.until-Date.now())/520);
    ctx.shadowColor='#fff7a8';ctx.shadowBlur=12+12*pulse;ctx.strokeStyle=`rgba(255,247,168,${Math.max(.35,life)*(.65+.35*pulse)})`;ctx.lineWidth=3+3*pulse;ctx.setLineDash([18,7]);
    ctx.beginPath();ctx.moveTo(0,guide.y);ctx.lineTo(canvas.width,guide.y);ctx.stroke();ctx.setLineDash([]);ctx.shadowBlur=0;
    const noun=state.mode==='cards'?'points':'objects',label=`${guide.row} ALIGNED  ·  y ${Math.round(guide.y)}  ·  ${guide.count} ${noun}`;
    ctx.font='bold 15px system-ui';const labelWidth=ctx.measureText(label).width+22,anchorX=state.mode==='cards'?state.quads[state.active][0].x:activeRects()[state.active].x;
    const labelX=Math.max(8,Math.min(canvas.width-labelWidth-8,anchorX));ctx.fillStyle='rgba(31,31,24,.9)';ctx.fillRect(labelX,guide.y-31,labelWidth,24);ctx.fillStyle='#fff7a8';ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillText(label,labelX+11,guide.y-19);
  });
  ctx.restore();
  if(!state.animationFrame)state.animationFrame=requestAnimationFrame(()=>{state.animationFrame=null;draw();});
}
function drawAngleMatches(){
  state.angleMatches=state.angleMatches.filter(match=>Date.now()<=match.until);if(!state.angleMatches.length)return;
  const pulse=.55+.45*Math.sin(Date.now()/42),quads=activeQuads();ctx.save();
  state.angleMatches.forEach(match=>{
    const life=Math.max(0,(match.until-Date.now())/520),activeQuad=quads[state.active];let label,a,b;
    if(match.kind==='internal'){
      ctx.strokeStyle=`rgba(126,240,192,${Math.max(.45,life)})`;ctx.shadowColor='#7ef0c0';ctx.lineWidth=5+3*pulse;ctx.shadowBlur=12+10*pulse;
      match.edges.forEach(edgeIndex=>{const edge=quadEdges[edgeIndex],p0=activeQuad[edge.points[0]],p1=activeQuad[edge.points[1]];ctx.beginPath();ctx.moveTo(p0.x,p0.y);ctx.lineTo(p1.x,p1.y);ctx.stroke();});
      const first=quadEdges[match.edges[0]],second=quadEdges[match.edges[1]];a=activeQuad[first.points[0]];b=activeQuad[first.points[1]];label=`${first.name} ↔ ${second.name} ANGLE MATCH  ·  Δ ${match.delta.toFixed(1)}°`;
    }else{
      const edge=quadEdges[match.edge];ctx.strokeStyle=`rgba(143,231,255,${Math.max(.45,life)})`;ctx.lineWidth=5+3*pulse;ctx.shadowColor='#8fe7ff';ctx.shadowBlur=12+10*pulse;
      match.indices.forEach(index=>{const q=quads[index],p0=q[edge.points[0]],p1=q[edge.points[1]];ctx.beginPath();ctx.moveTo(p0.x,p0.y);ctx.lineTo(p1.x,p1.y);ctx.stroke();});a=activeQuad[edge.points[0]];b=activeQuad[edge.points[1]];label=`${edge.name} ANGLE MATCH  ·  ${match.angle.toFixed(1)}°  ·  ${match.indices.length} objects`;
    }
    ctx.shadowBlur=0;ctx.font='bold 15px system-ui';const labelWidth=ctx.measureText(label).width+22,labelX=Math.max(8,Math.min(canvas.width-labelWidth-8,(a.x+b.x)/2-labelWidth/2)),labelY=Math.max(8,Math.min(canvas.height-30,(a.y+b.y)/2-34));ctx.fillStyle=match.kind==='internal'?'rgba(23,48,38,.94)':'rgba(20,42,48,.94)';ctx.fillRect(labelX,labelY,labelWidth,24);ctx.fillStyle=match.kind==='internal'?'#a9ffd7':'#bcefff';ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillText(label,labelX+11,labelY+12);
  });ctx.restore();
  if(!state.animationFrame)state.animationFrame=requestAnimationFrame(()=>{state.animationFrame=null;draw();});
}
function drawSizeMatch(){
  const match=state.sizeMatch;if(!match||Date.now()>match.until){state.sizeMatch=null;return;}
  const pulse=.55+.45*Math.sin(Date.now()/42),life=Math.max(0,(match.until-Date.now())/520);ctx.save();ctx.setLineDash([12,6]);ctx.strokeStyle=`rgba(126,240,192,${Math.max(.45,life)})`;ctx.lineWidth=4+3*pulse;ctx.shadowColor='#7ef0c0';ctx.shadowBlur=10+10*pulse;
  const rects=activeRects();match.indices.forEach(index=>{const r=rects[index];ctx.strokeRect(r.x-5,r.y-5,r.width+10,r.height+10);});ctx.setLineDash([]);ctx.shadowBlur=0;
  const active=rects[state.active],label=`SIZE MATCH  ·  ${Math.round(match.width)} × ${Math.round(match.height)}  ·  ${match.indices.length} objects`;ctx.font='bold 15px system-ui';const labelWidth=ctx.measureText(label).width+22,labelX=Math.max(8,Math.min(canvas.width-labelWidth-8,active.x)),labelY=active.y+active.height+10;ctx.fillStyle='rgba(23,48,38,.94)';ctx.fillRect(labelX,labelY,labelWidth,24);ctx.fillStyle='#a9ffd7';ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillText(label,labelX+11,labelY+12);ctx.restore();
  if(!state.animationFrame)state.animationFrame=requestAnimationFrame(()=>{state.animationFrame=null;draw();});
}
function draw(){
  if(!state.config)return;drawBase();
  if(state.screen==='fields'){
    if($('#show-preview').checked){ctx.globalAlpha=.72;state.fieldQuads.fieldJobPiles.forEach(q=>drawWarp(state.preview,q));ctx.globalAlpha=1;}
    if(state.images.sign)state.fieldQuads.fieldJobSigns.forEach(drawSign);
    drawRectGroup(state.fieldRects.fieldJobPiles,'fieldJobPiles','#ff36d7','JOB PILE');
    drawRectGroup(state.fieldRects.fieldJobSigns,'fieldJobSigns','#c6f36b','JOB SIGN');
  }else{
    if($('#show-preview').checked){ctx.globalAlpha=.72;state.plotQuads.crossroads.forEach(q=>drawWarp(state.preview,q));ctx.globalAlpha=1;}
    if(state.images.sign)state.plotQuads.jobSigns.forEach(drawSign);
    drawRectGroup(state.plotRects.portraits,'portraits','#00dcff','PORTRAIT');
    drawRectGroup(state.plotRects.names,'names','#77d08b','NAME');
    drawRectGroup(state.plotRects.plotCards,'plotCards','#ff36d7','PLOT CARDS');
    drawRectGroup(state.plotRects.cellarCounts,'cellarCounts','#f3a444','CELLAR');
    drawRectGroup(state.plotRects.jobSigns,'jobSigns','#c6f36b','JOB SIGN');
    drawRectGroup(state.plotRects.crossroads,'crossroads','#ff36d7','TRICK CARD');
    drawRectGroup(state.plotRects.planning,'planning','#77d08b','PLANNING');
  }
  drawSizeMatch();drawAlignment();drawAngleMatches();
}
function formatNumber(n){const s=(Math.round(n*1000)/1000).toFixed(3);return s.replace(/0+$/,'').replace(/\.$/,'');}
function backgroundSourcePoint(p){const [left,top,width,height]=state.config.boardRect,{width:sourceWidth,height:sourceHeight}=state.config.backgroundSourceSize,scale=Math.min(width/sourceWidth,height/sourceHeight),offsetX=left+(width-sourceWidth*scale)/2,offsetY=top+(height-sourceHeight*scale)/2;return{x:(p.x-offsetX)/scale,y:(p.y-offsetY)/scale};}
function backgroundSourceRect(r){const a=backgroundSourcePoint(r),b=backgroundSourcePoint({x:r.x+r.width,y:r.y+r.height});return{x:a.x,y:a.y,width:b.x-a.x,height:b.y-a.y};}
function migrateCoverPointToContain(p){
  const [left,top,width,height]=state.config.boardRect,{width:sourceWidth,height:sourceHeight}=state.config.backgroundSourceSize;
  const oldScale=Math.max(width/sourceWidth,height/sourceHeight),oldX=left+(width-sourceWidth*oldScale)/2,oldY=top+(height-sourceHeight*oldScale)/2;
  const source={x:(p.x-oldX)/oldScale,y:(p.y-oldY)/oldScale};
  const newScale=Math.min(width/sourceWidth,height/sourceHeight),newX=left+(width-sourceWidth*newScale)/2,newY=top+(height-sourceHeight*newScale)/2;
  return{x:newX+source.x*newScale,y:newY+source.y*newScale};
}
function migrateCoverRectsToContain(groups){return Object.fromEntries(Object.entries(groups).map(([group,rects])=>[group,rects.map(rect=>{const a=migrateCoverPointToContain(rect),b=migrateCoverPointToContain({x:rect.x+rect.width,y:rect.y+rect.height});return{x:a.x,y:a.y,width:b.x-a.x,height:b.y-a.y};})]));}
function migrateCoverQuadsToContain(groups){return Object.fromEntries(Object.entries(groups).map(([group,quads])=>[group,quads.map(quad=>quad.map(migrateCoverPointToContain))]));}
function cardDartOutput(){
  const lines=['// Coordinates are pixels in trick-field-light.png.','FieldPlanCardQuad fieldPlanCardSourceQuad(int seatID) => switch (seatID) {'];
  state.config.seatIds.forEach((seat,i)=>{const q=state.quads[i].map(backgroundSourcePoint);lines.push(`  ${seat} => const FieldPlanCardQuad(`);q.forEach(p=>lines.push(`    Offset(${formatNumber(p.x)}, ${formatNumber(p.y)}),`));lines.push('  ),');});
  lines.push('};');return lines.join('\n');
}
function signDartOutput(){
  const lines=['// Coordinates are pixels in trick-field-light.png.','Rect fieldPlanSignSourceRect(int seatID) => switch (seatID) {'];
  state.config.seatIds.forEach((seat,i)=>{const topLeft=backgroundSourcePoint(state.signRects[i]),bottomRight=backgroundSourcePoint({x:state.signRects[i].x+state.signRects[i].width,y:state.signRects[i].y+state.signRects[i].height}),r={x:topLeft.x,y:topLeft.y,width:bottomRight.x-topLeft.x,height:bottomRight.y-topLeft.y};lines.push(`  ${seat} => const Rect.fromLTWH(`);lines.push(`    ${formatNumber(r.x)}, ${formatNumber(r.y)}, ${formatNumber(r.width)}, ${formatNumber(r.height)},`);lines.push('  ),');});
  lines.push('};');return lines.join('\n');
}
function rectDartOutput(name,rects,source='brigade-plot-light.png'){const lines=[`// Coordinates are pixels in ${source}.`,`Rect ${name}(int index) => switch (index) {`];rects.forEach((rect,i)=>{const r=backgroundSourceRect(rect);lines.push(`  ${i} => const Rect.fromLTWH(${formatNumber(r.x)}, ${formatNumber(r.y)}, ${formatNumber(r.width)}, ${formatNumber(r.height)}),`);});lines.push("  _ => throw RangeError.index(index, const <Object>[]),",'};');return lines.join('\n');}
function quadDartOutput(name,quads,source='brigade-plot-light.png'){const lines=[`// Perspective corners are pixels in ${source}.`,`FieldPlanCardQuad ${name}(int index) => switch (index) {`];quads.forEach((quad,i)=>{lines.push(`  ${i} => const FieldPlanCardQuad(`);quad.map(backgroundSourcePoint).forEach(p=>lines.push(`    Offset(${formatNumber(p.x)}, ${formatNumber(p.y)}),`));lines.push('  ),');});lines.push("  _ => throw RangeError.index(index, const <Object>[]),",'};');return lines.join('\n');}
function plotDartOutput(){return [
  rectDartOutput('fieldPlanPlayerPortraitSourceRect',state.plotRects.portraits),quadDartOutput('fieldPlanPlayerPortraitSourceQuad',state.plotQuads.portraits),
  rectDartOutput('fieldPlanPlayerNameSourceRect',state.plotRects.names),quadDartOutput('fieldPlanPlayerNameSourceQuad',state.plotQuads.names),
  rectDartOutput('fieldPlanPlotCardsSourceRect',state.plotRects.plotCards),quadDartOutput('fieldPlanPlotCardsSourceQuad',state.plotQuads.plotCards),
  rectDartOutput('fieldPlanCellarCountSourceRect',state.plotRects.cellarCounts),quadDartOutput('fieldPlanCellarCountSourceQuad',state.plotQuads.cellarCounts),
  rectDartOutput('fieldPlanJobSignSourceRect',state.plotRects.jobSigns),quadDartOutput('fieldPlanJobSignSourceQuad',state.plotQuads.jobSigns),
  rectDartOutput('fieldPlanCrossroadsCardSourceRect',state.plotRects.crossroads),quadDartOutput('fieldPlanCrossroadsCardSourceQuad',state.plotQuads.crossroads),
  rectDartOutput('fieldPlanPlanningSourceRect',state.plotRects.planning),quadDartOutput('fieldPlanPlanningSourceQuad',state.plotQuads.planning),
].join('\n\n');}
function fieldsDartOutput(){return [
  rectDartOutput('fieldPlanFieldsJobPileSourceRect',state.fieldRects.fieldJobPiles,'fields-light.png'),quadDartOutput('fieldPlanFieldsJobPileSourceQuad',state.fieldQuads.fieldJobPiles,'fields-light.png'),
  rectDartOutput('fieldPlanFieldsJobSignSourceRect',state.fieldRects.fieldJobSigns,'fields-light.png'),quadDartOutput('fieldPlanFieldsJobSignSourceQuad',state.fieldQuads.fieldJobSigns,'fields-light.png'),
].join('\n\n');}
function dartOutput(){return state.screen==='fields'?fieldsDartOutput():plotDartOutput();}
function persist(){localStorage.setItem(plotStorageKey,JSON.stringify(state.plotRects));localStorage.setItem(plotQuadStorageKey,JSON.stringify(state.plotQuads));localStorage.setItem(fieldStorageKey,JSON.stringify(state.fieldRects));localStorage.setItem(fieldQuadStorageKey,JSON.stringify(state.fieldQuads));updateOutput();draw();}
function updateOutput(){$('#output').value=dartOutput();}
function rebuildButtons(){const buttons=$('#card-buttons');buttons.innerHTML='';const count=state.mode==='cards'||state.mode==='signs'?state.config.seatIds.length:activeRects().length;$('#item-heading').textContent=state.screen==='fields'?'Job':state.mode==='planning'?'Element':'Seat / element';for(let i=0;i<count;i++){const b=document.createElement('button');b.textContent=state.mode==='cards'||state.mode==='signs'?`${i+1} · seat ${state.config.seatIds[i]}`:itemLabel(state.mode,i);b.onclick=()=>setActive(i);buttons.appendChild(b);}setActive(Math.min(state.active,Math.max(0,count-1)));}
function setActive(i){state.active=i;state.handle=null;state.alignment=[];state.angleMatches=[];state.sizeMatch=null;document.querySelectorAll('.cards button').forEach((b,j)=>b.classList.toggle('active',j===i));draw();}
function setMode(mode){state.mode=mode;state.handle=null;state.drag=null;state.alignment=[];state.angleMatches=[];state.sizeMatch=null;document.querySelectorAll('#modes button').forEach(b=>b.classList.toggle('active',b.id===`edit-${mode}`));rebuildButtons();updateOutput();draw();}
function setScreen(screen){
  state.screen=screen;state.active=0;state.handle=null;state.drag=null;state.alignment=[];state.angleMatches=[];state.sizeMatch=null;
  $('#screen-farmstead').classList.toggle('active',screen==='farmstead');$('#screen-fields').classList.toggle('active',screen==='fields');
  document.querySelectorAll('[data-screen]').forEach(el=>el.hidden=el.dataset.screen!==screen);
  const farmsteadModes=['portraits','names','plotCards','cellarCounts','jobSigns','crossroads','planning'];
  document.querySelectorAll('#modes button').forEach(button=>button.hidden=screen==='fields'?!['edit-fieldJobPiles','edit-fieldJobSigns'].includes(button.id):!farmsteadModes.includes(button.id.replace('edit-','')));
  $('#page-title').textContent=screen==='fields'?'Fields / Assignment Layout Editor':'Brigade / Plot Layout Editor';
  $('#page-subtitle').textContent=screen==='fields'?'Position the four job piles and their job signs against the working fields plate.':'Position Flutter overlays against the farmstead plate.';
  setMode(screen==='fields'?'fieldJobPiles':'portraits');
}
function status(text){$('#status').textContent=text;setTimeout(()=>{if($('#status').textContent===text)$('#status').textContent='';},2200);}
canvas.addEventListener('pointerdown',e=>{const p=imagePoint(e),skew=$('#skew-mode').checked,rects=activeRects(),quads=activeQuads();let best=null;quads.forEach((corners,i)=>corners.forEach((h,j)=>{const d=Math.hypot(h.x-p.x,h.y-p.y);if(d<18&&(!best||d<best.d))best={i,j,d};}));if(best){setActive(best.i);state.handle=best.j;state.drag=skew?{kind:'quad-handle',start:p}:{kind:'rect-handle',start:p,original:clone(rects[best.i])};}else{for(let i=quads.length-1;i>=0;i--)if(pointInQuad(p,quads[i])){setActive(i);state.drag=skew?{kind:'quad',start:p,original:clone(quads[i])}:{kind:'rect',start:p,original:clone(rects[i]),originalQuad:clone(quads[i])};break;}}if(state.drag){canvas.setPointerCapture(e.pointerId);e.preventDefault();}});
canvas.addEventListener('pointermove',e=>{if(!state.drag)return;const p=imagePoint(e),rects=activeRects(),quads=activeQuads();if(state.drag.kind==='quad-handle'){quads[state.active][state.handle]=p;rects[state.active]=quadBounds(quads[state.active]);}else if(state.drag.kind==='quad'){const dx=p.x-state.drag.start.x,dy=p.y-state.drag.start.y;quads[state.active]=state.drag.original.map(v=>({x:v.x+dx,y:v.y+dy}));rects[state.active]=quadBounds(quads[state.active]);}else if(state.drag.kind==='rect-handle'){rects[state.active]=resizedRect(state.drag.original,state.handle,p);quads[state.active]=rectCorners(rects[state.active]);}else{const dx=p.x-state.drag.start.x,dy=p.y-state.drag.start.y;rects[state.active]={...state.drag.original,x:state.drag.original.x+dx,y:state.drag.original.y+dy};quads[state.active]=state.drag.originalQuad.map(v=>({x:v.x+dx,y:v.y+dy}));}updateAlignment();updateOutput();draw();});
canvas.addEventListener('pointerup',e=>{if(state.drag){updateAlignment();state.drag=null;persist();canvas.releasePointerCapture(e.pointerId);}});
window.addEventListener('keydown',e=>{if(state.handle==null||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;const d=e.shiftKey?10:1,dx=e.key==='ArrowLeft'?-d:e.key==='ArrowRight'?d:0,dy=e.key==='ArrowUp'?-d:e.key==='ArrowDown'?d:0,rects=activeRects(),quads=activeQuads();if($('#skew-mode').checked){const p=quads[state.active][state.handle];p.x+=dx;p.y+=dy;rects[state.active]=quadBounds(quads[state.active]);}else{const original=clone(rects[state.active]),p=rectCorners(original)[state.handle];rects[state.active]=resizedRect(original,state.handle,{x:p.x+dx,y:p.y+dy});quads[state.active]=rectCorners(rects[state.active]);}updateAlignment();e.preventDefault();persist();});
async function init(){
  state.config=await fetch('/config.json').then(r=>r.json());canvas.width=state.config.canvas.width;canvas.height=state.config.canvas.height;
  state.images.plotBackground=await loadImage('/plot-background.png');state.images.fieldsBackground=await loadImage('/fields-background.png');state.images.sign=await loadImage('/sign.png');state.preview=makePreview();
  const savedPlot=localStorage.getItem(plotStorageKey),savedQuads=localStorage.getItem(plotQuadStorageKey),savedFields=localStorage.getItem(fieldStorageKey),savedFieldQuads=localStorage.getItem(fieldQuadStorageKey),needsContainMigration=savedPlot&&!localStorage.getItem(containMigrationKey);
  state.plotRects=savedPlot?JSON.parse(savedPlot):clone(state.config.plotRects);if(needsContainMigration)state.plotRects=migrateCoverRectsToContain(state.plotRects);const defaultQuads=Object.fromEntries(Object.entries(state.plotRects).map(([group,rects])=>[group,rects.map(rectCorners)]));const restoredQuads=savedQuads?JSON.parse(savedQuads):null;state.plotQuads=restoredQuads?{...defaultQuads,...(needsContainMigration?migrateCoverQuadsToContain(restoredQuads):restoredQuads)}:defaultQuads;if(needsContainMigration){localStorage.setItem(plotStorageKey,JSON.stringify(state.plotRects));localStorage.setItem(plotQuadStorageKey,JSON.stringify(state.plotQuads));localStorage.setItem(containMigrationKey,'1');}
  state.fieldRects=savedFields?JSON.parse(savedFields):clone(state.config.fieldRects);const defaultFieldQuads=Object.fromEntries(Object.entries(state.fieldRects).map(([group,rects])=>[group,rects.map(rectCorners)]));state.fieldQuads=savedFieldQuads?{...defaultFieldQuads,...JSON.parse(savedFieldQuads)}:defaultFieldQuads;
  setScreen(new URLSearchParams(location.search).get('screen')==='fields'?'fields':'farmstead');
}
$('#show-preview').addEventListener('change',draw);
$('#skew-mode').addEventListener('change',()=>{state.handle=null;state.drag=null;state.alignment=[];state.angleMatches=[];state.sizeMatch=null;draw();});
$('#edit-portraits').onclick=()=>setMode('portraits');
$('#edit-names').onclick=()=>setMode('names');
$('#edit-plotCards').onclick=()=>setMode('plotCards');
$('#edit-cellarCounts').onclick=()=>setMode('cellarCounts');
$('#edit-jobSigns').onclick=()=>setMode('jobSigns');
$('#edit-crossroads').onclick=()=>setMode('crossroads');
$('#edit-planning').onclick=()=>setMode('planning');
$('#edit-fieldJobPiles').onclick=()=>setMode('fieldJobPiles');
$('#edit-fieldJobSigns').onclick=()=>setMode('fieldJobSigns');
$('#screen-farmstead').onclick=()=>setScreen('farmstead');
$('#screen-fields').onclick=()=>setScreen('fields');
$('#reset').onclick=()=>{const rects=currentRects(),quads=currentQuads(),defaults=state.screen==='fields'?state.config.fieldRects:state.config.plotRects;rects[state.mode][state.active]=clone(defaults[state.mode][state.active]);quads[state.mode][state.active]=rectCorners(rects[state.mode][state.active]);persist();};
$('#reset-all').onclick=()=>{const rects=currentRects(),quads=currentQuads(),defaults=state.screen==='fields'?state.config.fieldRects:state.config.plotRects;rects[state.mode]=clone(defaults[state.mode]);quads[state.mode]=rects[state.mode].map(rectCorners);persist();};
$('#copy').onclick=async()=>{await navigator.clipboard.writeText(dartOutput());status('Dart copied to clipboard.');};
$('#download').onclick=()=>{const data={canvas:state.config.canvas,boardRect:state.config.boardRect,seatIds:state.config.seatIds,plotRects:state.plotRects,plotQuads:state.plotQuads,fieldRects:state.fieldRects,fieldQuads:state.fieldQuads};const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));a.download='field-plan-calibration.json';a.click();URL.revokeObjectURL(a.href);status('Calibration JSON downloaded.');};
init().catch(error=>{document.body.innerHTML=`<pre style="padding:20px;color:#ff9b8c">${error.stack||error}</pre>`;});
</script>
</body>
</html>
"""


def calibration_config() -> dict[str, object]:
    width, height = (1334, 750)
    if SOURCE.exists():
        with Image.open(SOURCE) as image:
            width, height = image.size
    def source_rect_to_canvas(rect: dict[str, float]) -> dict[str, float]:
        left, top, board_width, board_height = BOARD_RECT
        source_width, source_height = (1672, 941)
        scale = min(board_width / source_width, board_height / source_height)
        offset_x = left + (board_width - source_width * scale) / 2
        offset_y = top + (board_height - source_height * scale) / 2
        return {
            "x": offset_x + rect["x"] * scale,
            "y": offset_y + rect["y"] * scale,
            "width": rect["width"] * scale,
            "height": rect["height"] * scale,
        }

    return {
        "canvas": {"width": width, "height": height},
        "boardRect": BOARD_RECT,
        "backgroundSourceSize": {"width": 1672, "height": 941},
        "parcels": [
            [{"x": x, "y": y} for x, y in parcel] for parcel in rendered_parcels()
        ],
        "cardQuads": [
            [{"x": x, "y": y} for x, y in quad] for quad in CARD_QUADS
        ],
        "seatIds": SEAT_IDS,
        "slotRects": card_slot_rects(),
        "signRects": [dict(rect) for rect in SIGN_RECTS],
        "plotRects": {
            "portraits": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_PORTRAIT_SOURCE_RECTS
            ],
            "names": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_NAME_SOURCE_RECTS
            ],
            "plotCards": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_PLOT_CARD_SOURCE_RECTS
            ],
            "cellarCounts": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_CELLAR_COUNT_SOURCE_RECTS
            ],
            "jobSigns": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_JOB_SIGN_SOURCE_RECTS
            ],
            "crossroads": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_CARD_SOURCE_RECTS
            ],
            "planning": [
                source_rect_to_canvas(rect)
                for rect in BRIGADE_PLOT_PLANNING_SOURCE_RECTS
            ],
        },
        "fieldRects": {
            "fieldJobPiles": [
                source_rect_to_canvas(rect)
                for rect in FIELDS_JOB_PILE_SOURCE_RECTS
            ],
            "fieldJobSigns": [
                source_rect_to_canvas(rect)
                for rect in FIELDS_JOB_SIGN_SOURCE_RECTS
            ],
        },
    }


class CalibrationHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            self.send_bytes(HTML.encode(), "text/html; charset=utf-8")
        elif path == "/config.json":
            self.send_bytes(
                json.dumps(calibration_config()).encode(),
                "application/json; charset=utf-8",
            )
        elif path == "/source.png":
            self.send_file(SOURCE, "image/png")
        elif path == "/background.png":
            self.send_file(BACKGROUND, "image/png")
        elif path == "/plot-background.png":
            self.send_file(BRIGADE_PLOT_BACKGROUND, "image/png")
        elif path == "/fields-background.png":
            self.send_file(FIELDS_BACKGROUND, "image/png")
        elif path == "/card.png":
            self.send_file(CARD, "image/png")
        elif path == "/sign.png":
            self.send_file(SIGN, "image/png")
        else:
            self.send_error(404)

    def send_file(self, path: Path, content_type: str) -> None:
        if not path.exists():
            self.send_error(404, f"Missing {path}")
            return
        self.send_bytes(path.read_bytes(), content_type)

    def send_bytes(self, body: bytes, content_type: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        print(f"{self.address_string()} - {format % args}")


def serve(host: str, port: int, open_browser: bool) -> None:
    server = ThreadingHTTPServer((host, port), CalibrationHandler)
    url = f"http://{host}:{server.server_port}"
    print(f"Field Plan layout editor: {url}")
    if open_browser:
        threading.Timer(0.25, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Calibrate Field Plan overlay layouts.")
    parser.add_argument(
        "--serve",
        action="store_true",
        help="start the interactive browser calibrator instead of generating PNG overlays",
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-open", action="store_true", help="do not open a browser")
    args = parser.parse_args()
    if args.serve:
        serve(args.host, args.port, not args.no_open)
    else:
        generate_images()


if __name__ == "__main__":
    main()
