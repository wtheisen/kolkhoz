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
<title>Field Plan Layout Calibration</title>
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
  .mode { display:grid; grid-template-columns:1fr 1fr; gap:6px; margin:8px 0; }
  .mode button.active { background:#315e3b; border-color:var(--green); }
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
<header><h1>Field Plan Layout Calibration</h1><span>Position the cards and player signs against the painted fields.</span></header>
<main>
  <div class="stage">
    <div class="canvas-wrap"><canvas id="canvas" width="1334" height="750"></canvas></div>
    <div class="legend">
      <span><i class="swatch" style="background:var(--cyan)"></i>background parcel</span>
      <span><i class="swatch" style="background:var(--pink)"></i>card destination</span>
      <span><i class="swatch" style="background:#f7e36d"></i>selected card</span>
      <span><i class="swatch" style="background:var(--green)"></i>player sign bounds</span>
      <span><i class="swatch" style="background:#fff7a8"></i>horizontal alignment</span>
      <span><i class="swatch" style="background:#7ef0c0"></i>matching sign size</span>
    </div>
  </div>
  <aside>
    <section>
      <h2>Seat</h2>
      <div class="cards" id="card-buttons"></div>
      <div class="mode"><button id="edit-cards" class="active">Edit cards</button><button id="edit-signs">Edit signs</button></div>
      <div class="checks">
        <label><span>Base image</span><select id="base"><option value="screenshot">Flutter screenshot</option><option value="background">Background only</option></select></label>
        <label><input id="show-preview" type="checkbox" checked> Show warped card preview</label>
        <label><input id="show-parcels" type="checkbox" checked> Show parcel guides</label>
        <label><input id="show-slots" type="checkbox"> Show Flutter card slots</label>
        <label><input id="show-signs" type="checkbox" checked> Show player signs</label>
      </div>
      <div class="row"><button id="fit">Fit selected to parcel</button><button id="reset">Reset selected</button></div>
      <div class="row"><button id="reset-all">Reset all</button><button id="download">Download JSON</button></div>
      <div id="status"></div>
    </section>
    <section>
      <h2>Controls</h2>
      <div class="help">Choose Cards or Signs, then drag a corner handle to resize or drag inside the selected object to move it. Cards and signs flash horizontal top/bottom guides. Signs also flash a mint outline when their width and height match another sign within 3 screenshot pixels. Arrow keys nudge the selected corner by one pixel; hold Shift for ten. Changes are retained in this browser.</div>
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
const state={config:null,quads:[],signRects:[],mode:'cards',active:0,handle:null,drag:null,images:{},preview:null,alignment:[],sizeMatch:null,animationFrame:null};
const $=s=>document.querySelector(s);
const clone=v=>JSON.parse(JSON.stringify(v));
const names=['TL','TR','BR','BL'];
const alignmentThreshold=3;
const cardStorageKey='field-plan-card-quads-v3';
const signStorageKey='field-plan-sign-rects-v2';
const signFaceFraction=566/846;
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
function drawSign(rect){
  const fullHeight=rect.height/signFaceFraction;
  ctx.drawImage(state.images.sign,rect.x,rect.y,rect.width,fullHeight);
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
  if($('#base').value==='screenshot'&&state.images.screenshot){ctx.drawImage(state.images.screenshot,0,0,canvas.width,canvas.height);return;}
  const [left,top,width,height]=state.config.boardRect,img=state.images.background;
  const scale=Math.max(width/img.width,height/img.height),dw=img.width*scale,dh=img.height*scale;
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
  const source=state.signRects[state.active],sourceY=edge==='top'?source.y:source.y+source.height,matches=[];
  state.signRects.forEach((rect,index)=>{if(index===state.active)return;const y=edge==='top'?rect.y:rect.y+rect.height;if(Math.abs(y-sourceY)<=alignmentThreshold)matches.push(y);});
  if(!matches.length)return null;
  const y=(sourceY+matches.reduce((sum,value)=>sum+value,0))/(matches.length+1);
  return{y,row:`SIGN ${edge.toUpperCase()}S`,count:matches.length+1,until:Date.now()+520};
}
function matchingSignSize(){
  if(state.mode!=='signs'||state.handle==null||state.drag?.kind==='sign')return null;
  const source=state.signRects[state.active],matches=[];
  state.signRects.forEach((rect,index)=>{if(index!==state.active&&Math.abs(rect.width-source.width)<=alignmentThreshold&&Math.abs(rect.height-source.height)<=alignmentThreshold)matches.push(index);});
  return matches.length?{indices:[state.active,...matches],width:source.width,height:source.height,until:Date.now()+520}:null;
}
function updateAlignment(){
  if(state.mode==='cards'){
    const guide=state.drag?.kind==='quad'?(alignedPoint(0)||alignedPoint(2)):state.handle!=null?alignedPoint(state.handle):null;
    state.alignment=guide?[guide]:[];state.sizeMatch=null;return;
  }
  const edges=state.drag?.kind==='sign'||state.handle==null?['top','bottom']:(state.handle<2?['top']:['bottom']);
  state.alignment=edges.map(alignedSignEdge).filter(Boolean);state.sizeMatch=matchingSignSize();
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
    const noun=state.mode==='signs'?'signs':'points',label=`${guide.row} ALIGNED  ·  y ${Math.round(guide.y)}  ·  ${guide.count} ${noun}`;
    ctx.font='bold 15px system-ui';const labelWidth=ctx.measureText(label).width+22,anchorX=state.mode==='signs'?state.signRects[state.active].x:state.quads[state.active][0].x;
    const labelX=Math.max(8,Math.min(canvas.width-labelWidth-8,anchorX));ctx.fillStyle='rgba(31,31,24,.9)';ctx.fillRect(labelX,guide.y-31,labelWidth,24);ctx.fillStyle='#fff7a8';ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillText(label,labelX+11,guide.y-19);
  });
  ctx.restore();
  if(!state.animationFrame)state.animationFrame=requestAnimationFrame(()=>{state.animationFrame=null;draw();});
}
function drawSizeMatch(){
  const match=state.sizeMatch;if(!match||Date.now()>match.until){state.sizeMatch=null;return;}
  const pulse=.55+.45*Math.sin(Date.now()/42),life=Math.max(0,(match.until-Date.now())/520);ctx.save();ctx.setLineDash([12,6]);ctx.strokeStyle=`rgba(126,240,192,${Math.max(.45,life)})`;ctx.lineWidth=4+3*pulse;ctx.shadowColor='#7ef0c0';ctx.shadowBlur=10+10*pulse;
  match.indices.forEach(index=>{const r=state.signRects[index];ctx.strokeRect(r.x-5,r.y-5,r.width+10,r.height+10);});ctx.setLineDash([]);ctx.shadowBlur=0;
  const active=state.signRects[state.active],label=`SIZE MATCH  ·  ${Math.round(match.width)} × ${Math.round(match.height)}  ·  ${match.indices.length} signs`;ctx.font='bold 15px system-ui';const labelWidth=ctx.measureText(label).width+22,labelX=Math.max(8,Math.min(canvas.width-labelWidth-8,active.x)),labelY=active.y+active.height+10;ctx.fillStyle='rgba(23,48,38,.94)';ctx.fillRect(labelX,labelY,labelWidth,24);ctx.fillStyle='#a9ffd7';ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillText(label,labelX+11,labelY+12);ctx.restore();
  if(!state.animationFrame)state.animationFrame=requestAnimationFrame(()=>{state.animationFrame=null;draw();});
}
function draw(){
  if(!state.config)return;drawBase();
  if($('#show-signs').checked&&state.images.sign)state.signRects.forEach(drawSign);
  if($('#show-preview').checked){ctx.globalAlpha=.82;state.quads.forEach(q=>drawWarp(state.preview,q));ctx.globalAlpha=1;}
  if($('#show-slots').checked){ctx.setLineDash([8,7]);state.config.slotRects.forEach(r=>{ctx.strokeStyle='#f3a444';ctx.lineWidth=2;ctx.strokeRect(r.x,r.y,r.width,r.height)});ctx.setLineDash([]);}
  if($('#show-parcels').checked)state.config.parcels.forEach(q=>polygon(q,'#00dcff',3));
  state.quads.forEach((q,i)=>{const active=state.mode==='cards'&&i===state.active,color=active?'#f7e36d':'#ff36d7';polygon(q,color,active?5:2);if(state.mode==='cards')q.forEach((p,j)=>{ctx.beginPath();ctx.arc(p.x,p.y,active?9:7,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();ctx.strokeStyle='#241d19';ctx.lineWidth=2;ctx.stroke();if(active){ctx.fillStyle='#211f18';ctx.font='bold 11px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(names[j][0],p.x,p.y+.5);}});});
  state.signRects.forEach((r,i)=>{const active=state.mode==='signs'&&i===state.active,color=active?'#f7e36d':'#77d08b',corners=rectCorners(r);ctx.strokeStyle=color;ctx.lineWidth=active?5:2;ctx.strokeRect(r.x,r.y,r.width,r.height);if(state.mode==='signs')corners.forEach((p,j)=>{ctx.beginPath();ctx.rect(p.x-(active?9:7),p.y-(active?9:7),(active?18:14),(active?18:14));ctx.fillStyle=color;ctx.fill();ctx.strokeStyle='#241d19';ctx.lineWidth=2;ctx.stroke();if(active){ctx.fillStyle='#211f18';ctx.font='bold 10px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(names[j][0],p.x,p.y+.5);}});});
  drawSizeMatch();
  drawAlignment();
}
function formatNumber(n){const s=(Math.round(n*1000)/1000).toFixed(3);return s.replace(/0+$/,'').replace(/\.$/,'');}
function normalizedQuad(i){const r=state.config.slotRects[i];return state.quads[i].map(p=>({x:(p.x-r.x)/r.width,y:(p.y-r.y)/r.height}));}
function cardDartOutput(){
  const lines=['FieldPlanCardQuad fieldPlanCardQuad(int seatID) => switch (seatID) {'];
  state.config.seatIds.forEach((seat,i)=>{const q=normalizedQuad(i);lines.push(`  ${seat} => const FieldPlanCardQuad(`);q.forEach(p=>lines.push(`    Offset(${formatNumber(p.x)}, ${formatNumber(p.y)}),`));lines.push('  ),');});
  lines.push('};');return lines.join('\n');
}
function normalizedSignRect(i){const [x,y,width,height]=state.config.boardRect,r=state.signRects[i];return{x:(r.x-x)/width,y:(r.y-y)/height,width:r.width/width,height:r.height/height};}
function signDartOutput(){
  const lines=['// Rect values are normalized to the Field Plan board bounds.','Rect fieldPlanSignRect(int seatID) => switch (seatID) {'];
  state.config.seatIds.forEach((seat,i)=>{const r=normalizedSignRect(i);lines.push(`  ${seat} => const Rect.fromLTWH(`);lines.push(`    ${formatNumber(r.x)}, ${formatNumber(r.y)}, ${formatNumber(r.width)}, ${formatNumber(r.height)},`);lines.push('  ),');});
  lines.push('};');return lines.join('\n');
}
function dartOutput(){return `${cardDartOutput()}\n\n${signDartOutput()}`;}
function persist(){localStorage.setItem(cardStorageKey,JSON.stringify(state.quads));localStorage.setItem(signStorageKey,JSON.stringify(state.signRects));updateOutput();draw();}
function updateOutput(){$('#output').value=dartOutput();}
function setActive(i){state.active=i;state.handle=null;state.alignment=[];state.sizeMatch=null;document.querySelectorAll('.cards button').forEach((b,j)=>b.classList.toggle('active',j===i));draw();}
function setMode(mode){state.mode=mode;state.handle=null;state.drag=null;state.alignment=[];state.sizeMatch=null;$('#edit-cards').classList.toggle('active',mode==='cards');$('#edit-signs').classList.toggle('active',mode==='signs');$('#fit').disabled=mode==='signs';draw();}
function status(text){$('#status').textContent=text;setTimeout(()=>{if($('#status').textContent===text)$('#status').textContent='';},2200);}
canvas.addEventListener('pointerdown',e=>{const p=imagePoint(e);let best=null;if(state.mode==='cards'){state.quads.forEach((q,i)=>q.forEach((h,j)=>{const d=Math.hypot(h.x-p.x,h.y-p.y);if(d<18&&(!best||d<best.d))best={i,j,d};}));if(best){setActive(best.i);state.handle=best.j;state.drag={kind:'handle',start:p};}else{for(let i=state.quads.length-1;i>=0;i--)if(pointInQuad(p,state.quads[i])){setActive(i);state.drag={kind:'quad',start:p,original:clone(state.quads[i])};break;}}}else{state.signRects.forEach((r,i)=>rectCorners(r).forEach((h,j)=>{const d=Math.hypot(h.x-p.x,h.y-p.y);if(d<18&&(!best||d<best.d))best={i,j,d};}));if(best){setActive(best.i);state.handle=best.j;state.drag={kind:'sign-handle',start:p,original:clone(state.signRects[best.i])};}else{for(let i=state.signRects.length-1;i>=0;i--)if(pointInRect(p,state.signRects[i])){setActive(i);state.drag={kind:'sign',start:p,original:clone(state.signRects[i])};break;}}}if(state.drag){canvas.setPointerCapture(e.pointerId);e.preventDefault();}});
canvas.addEventListener('pointermove',e=>{if(!state.drag)return;const p=imagePoint(e);if(state.drag.kind==='handle')state.quads[state.active][state.handle]=p;else if(state.drag.kind==='quad'){const dx=p.x-state.drag.start.x,dy=p.y-state.drag.start.y;state.quads[state.active]=state.drag.original.map(v=>({x:v.x+dx,y:v.y+dy}));}else if(state.drag.kind==='sign-handle')state.signRects[state.active]=resizedRect(state.drag.original,state.handle,p);else{const dx=p.x-state.drag.start.x,dy=p.y-state.drag.start.y;state.signRects[state.active]={...state.drag.original,x:state.drag.original.x+dx,y:state.drag.original.y+dy};}updateAlignment();updateOutput();draw();});
canvas.addEventListener('pointerup',e=>{if(state.drag){updateAlignment();state.drag=null;persist();canvas.releasePointerCapture(e.pointerId);}});
window.addEventListener('keydown',e=>{if(state.handle==null||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;const d=e.shiftKey?10:1,dx=e.key==='ArrowLeft'?-d:e.key==='ArrowRight'?d:0,dy=e.key==='ArrowUp'?-d:e.key==='ArrowDown'?d:0;if(state.mode==='cards'){const p=state.quads[state.active][state.handle];p.x+=dx;p.y+=dy;}else{const original=clone(state.signRects[state.active]),p=rectCorners(original)[state.handle];state.signRects[state.active]=resizedRect(original,state.handle,{x:p.x+dx,y:p.y+dy});}updateAlignment();e.preventDefault();persist();});
async function init(){
  state.config=await fetch('/config.json').then(r=>r.json());canvas.width=state.config.canvas.width;canvas.height=state.config.canvas.height;
  state.images.background=await loadImage('/background.png');try{state.images.screenshot=await loadImage('/source.png');}catch{$('#base').value='background';}
  state.images.sign=await loadImage('/sign.png');state.preview=makePreview();const savedCards=localStorage.getItem(cardStorageKey),savedSigns=localStorage.getItem(signStorageKey);state.quads=savedCards?JSON.parse(savedCards):clone(state.config.cardQuads);state.signRects=savedSigns?JSON.parse(savedSigns):clone(state.config.signRects);
  const buttons=$('#card-buttons');state.config.seatIds.forEach((seat,i)=>{const b=document.createElement('button');b.textContent=`${i+1} · seat ${seat}`;b.onclick=()=>setActive(i);buttons.appendChild(b);});setActive(0);updateOutput();draw();
}
['base','show-preview','show-parcels','show-slots','show-signs'].forEach(id=>$(`#${id}`).addEventListener('change',draw));
$('#edit-cards').onclick=()=>setMode('cards');
$('#edit-signs').onclick=()=>setMode('signs');
$('#fit').onclick=()=>{state.quads[state.active]=clone(state.config.parcels[state.active]);persist();};
$('#reset').onclick=()=>{if(state.mode==='cards')state.quads[state.active]=clone(state.config.cardQuads[state.active]);else state.signRects[state.active]=clone(state.config.signRects[state.active]);persist();};
$('#reset-all').onclick=()=>{if(state.mode==='cards')state.quads=clone(state.config.cardQuads);else state.signRects=clone(state.config.signRects);persist();};
$('#copy').onclick=async()=>{await navigator.clipboard.writeText(dartOutput());status('Dart copied to clipboard.');};
$('#download').onclick=()=>{const data={canvas:state.config.canvas,boardRect:state.config.boardRect,seatIds:state.config.seatIds,quads:state.quads,normalizedQuads:state.quads.map((_,i)=>normalizedQuad(i)),signRects:state.signRects,normalizedSignRects:state.signRects.map((_,i)=>normalizedSignRect(i))};const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));a.download='field-plan-calibration.json';a.click();URL.revokeObjectURL(a.href);status('Calibration JSON downloaded.');};
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
    return {
        "canvas": {"width": width, "height": height},
        "boardRect": BOARD_RECT,
        "parcels": [
            [{"x": x, "y": y} for x, y in parcel] for parcel in rendered_parcels()
        ],
        "cardQuads": [
            [{"x": x, "y": y} for x, y in quad] for quad in CARD_QUADS
        ],
        "seatIds": SEAT_IDS,
        "slotRects": card_slot_rects(),
        "signRects": [dict(rect) for rect in SIGN_RECTS],
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
    print(f"Field Plan card calibration: {url}")
    if open_browser:
        threading.Timer(0.25, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Calibrate Field Plan card homographies.")
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
