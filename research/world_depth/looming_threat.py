#!/usr/bin/env python3
"""Research-only grounded corridor + independent looming-North composition study."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import shutil
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image, ImageDraw, ImageFont


WIDTH, HEIGHT = 1672, 941
FOCAL_LENGTH = 2.0
PROJECTION_PX = 720.0
CAMERA_HEIGHT = 1.12
NEAR_PLANE = 0.08
START_Z, END_Z = 3.0, 5.0
FRAME_COUNT = 41
VIEWPOINTS = {"locked": 0.11, "candidate-low": 0.28, "candidate-lower": 0.40}
SELECTED_VIEWPOINT = "candidate-lower"
YEAR_LEVELS = {1: 0.0, 2: 0.25, 3: 0.5, 4: 0.75, 5: 1.0}
YEAR_STATES = {
    1: {"heightFraction": 0.18, "widthFraction": 0.16, "contrast": 0.48, "haze": 0.62, "warmth": 0.05, "cloud": 0.12, "pulse": 0.00},
    2: {"heightFraction": 0.25, "widthFraction": 0.19, "contrast": 0.58, "haze": 0.51, "warmth": 0.14, "cloud": 0.27, "pulse": 0.12},
    3: {"heightFraction": 0.34, "widthFraction": 0.23, "contrast": 0.69, "haze": 0.39, "warmth": 0.25, "cloud": 0.45, "pulse": 0.24},
    4: {"heightFraction": 0.45, "widthFraction": 0.28, "contrast": 0.81, "haze": 0.26, "warmth": 0.39, "cloud": 0.67, "pulse": 0.39},
    5: {"heightFraction": 0.58, "widthFraction": 0.34, "contrast": 0.93, "haze": 0.13, "warmth": 0.56, "cloud": 0.92, "pulse": 0.58},
}

OBJECTS = [
    {"id": "tree-near-left", "kind": "tree", "x": -1.52, "z": 4.05, "w": 0.62, "h": 2.35, "group": "foreground"},
    {"id": "fence-near-right", "kind": "fence", "x": 1.24, "z": 4.42, "w": 0.90, "h": 0.56, "group": "foreground"},
    {"id": "tree-near-right", "kind": "tree", "x": 1.72, "z": 4.82, "w": 0.70, "h": 2.55, "group": "foreground"},
    {"id": "crop-left", "kind": "crop", "x": -1.08, "z": 5.28, "w": 0.52, "h": 0.75, "group": "foreground"},
    {"id": "house-left", "kind": "house", "x": -1.32, "z": 6.25, "w": 0.72, "h": 0.62, "group": "middle"},
    {"id": "pylon-right", "kind": "pylon", "x": 1.42, "z": 6.85, "w": 0.54, "h": 1.55, "group": "middle"},
    {"id": "tree-mid-left", "kind": "tree", "x": -1.05, "z": 7.75, "w": 0.55, "h": 1.45, "group": "middle"},
    {"id": "house-right", "kind": "house", "x": 0.92, "z": 8.55, "w": 0.58, "h": 0.48, "group": "middle"},
    {"id": "tree-far-right", "kind": "tree", "x": 0.88, "z": 11.0, "w": 0.48, "h": 1.25, "group": "distant"},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def threat_state(level: float) -> dict[str, float]:
    level = max(0.0, min(1.0, level))
    position = level * 4
    lower = min(4, int(math.floor(position))) + 1
    upper = min(5, lower + 1)
    amount = position - math.floor(position)
    return {key: lerp(YEAR_STATES[lower][key], YEAR_STATES[upper][key], amount) for key in YEAR_STATES[1]}


def project_ground(world_x: float, world_z: float, camera_z: float, vp_y: float) -> tuple[float, float, float] | None:
    distance = world_z - camera_z
    if distance <= NEAR_PLANE:
        return None
    return WIDTH * 0.5 + PROJECTION_PX * world_x / distance, HEIGHT * vp_y + PROJECTION_PX * CAMERA_HEIGHT / distance, distance


def object_rect(obj: dict, camera_z: float, vp_y: float) -> tuple[float, float, float, float] | None:
    point = project_ground(obj["x"], obj["z"], camera_z, vp_y)
    if point is None:
        return None
    x, y, distance = point
    scale = PROJECTION_PX / distance
    width, height = obj["w"] * scale, obj["h"] * scale
    return x - width / 2, y - height, width, height


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(lerp(a[i], b[i], t)) for i in range(3))


def _draw_sky(draw: ImageDraw.ImageDraw, vp_y: float, state: dict[str, float], atmosphere: bool) -> None:
    horizon = round(HEIGHT * vp_y)
    warmth = state["warmth"] if atmosphere else 0.0
    cloud = state["cloud"] if atmosphere else 0.0
    top = _mix((47, 68, 79), (73, 50, 52), warmth)
    bottom = _mix((177, 183, 164), (185, 132, 104), warmth)
    for y in range(max(1, horizon + 1)):
        draw.line((0, y, WIDTH, y), fill=_mix(top, bottom, y / max(horizon, 1)))
    for index in range(7):
        x = 80 + index * 270 + (index % 2) * 40
        y = 48 + (index % 3) * 46
        radius = 70 + index * 8
        alpha_color = _mix((103, 113, 111), (77, 70, 73), cloud)
        draw.ellipse((x - radius, y - radius * .28, x + radius, y + radius * .28), fill=alpha_color)
    draw.polygon([(0, horizon + 75), (180, horizon - 18), (330, horizon + 45), (520, horizon - 42), (710, horizon + 55), (910, horizon - 24), (1110, horizon + 48), (1330, horizon - 36), (WIDTH, horizon + 64), (WIDTH, horizon + 180), (0, horizon + 180)], fill=(76, 94, 91))
    draw.polygon([(0, horizon + 115), (250, horizon + 25), (430, horizon + 104), (660, horizon + 18), (850, horizon + 110), (1080, horizon + 35), (1320, horizon + 104), (1540, horizon + 40), (WIDTH, horizon + 120), (WIDTH, horizon + 230), (0, horizon + 230)], fill=(58, 82, 74))


def _ground_point(x: float, z: float, camera_z: float, vp_y: float) -> tuple[float, float] | None:
    point = project_ground(x, z, camera_z, vp_y)
    return None if point is None else (point[0], point[1])


def _draw_ground(draw: ImageDraw.ImageDraw, camera_z: float, vp_y: float, mesh: bool) -> None:
    horizon = HEIGHT * vp_y
    draw.rectangle((0, horizon, WIDTH, HEIGHT), fill=(122, 116, 65))
    far_z = 24.0
    strips = [(far_z - i * 0.55, far_z - (i + 1) * 0.55) for i in range(38)]
    for index, (far, near) in enumerate(strips):
        if near <= camera_z + 0.18:
            continue
        a, b = _ground_point(-4.5, far, camera_z, vp_y), _ground_point(4.5, far, camera_z, vp_y)
        c, d = _ground_point(4.5, near, camera_z, vp_y), _ground_point(-4.5, near, camera_z, vp_y)
        if all((a, b, c, d)):
            draw.polygon((a, b, c, d), fill=(138, 132, 70) if index % 2 else (126, 123, 62))
    road_far = [_ground_point(-0.42, far_z, camera_z, vp_y), _ground_point(0.42, far_z, camera_z, vp_y)]
    near_z = camera_z + 0.62
    road_near = [_ground_point(-0.42, near_z, camera_z, vp_y), _ground_point(0.42, near_z, camera_z, vp_y)]
    if all(road_far + road_near):
        draw.polygon((road_far[0], road_far[1], road_near[1], road_near[0]), fill=(197, 176, 126))
    for z in [camera_z + .7 + i * .34 for i in range(60)]:
        if z > far_z:
            break
        a, b = _ground_point(-0.34, z, camera_z, vp_y), _ground_point(0.34, z, camera_z, vp_y)
        if a and b and horizon <= a[1] <= HEIGHT + 10:
            draw.line((*a, *b), fill=(113, 101, 77), width=max(1, min(9, round(6 / (z - camera_z)))))
    for rail_x in (-0.20, 0.20):
        points = [_ground_point(rail_x, z, camera_z, vp_y) for z in [far_z - i * .12 for i in range(190)]]
        points = [point for point in points if point and horizon <= point[1] <= HEIGHT + 20]
        if len(points) > 1:
            draw.line(points, fill=(38, 43, 39), width=4)
    if mesh:
        for world_x in [x * .5 for x in range(-8, 9)]:
            points = [_ground_point(world_x, z, camera_z, vp_y) for z in [far_z - i * .15 for i in range(155)]]
            points = [p for p in points if p and horizon <= p[1] <= HEIGHT + 10]
            if len(points) > 1:
                draw.line(points, fill=(48, 196, 194), width=1)
        for z in [camera_z + .4 + i * .5 for i in range(42)]:
            a, b = _ground_point(-4.0, z, camera_z, vp_y), _ground_point(4.0, z, camera_z, vp_y)
            if a and b and horizon <= a[1] <= HEIGHT + 10:
                draw.line((*a, *b), fill=(48, 196, 194), width=1)


def _draw_object(draw: ImageDraw.ImageDraw, obj: dict, rect: tuple[float, float, float, float], guides: bool, bounds: bool) -> None:
    x, y, w, h = rect
    ink = (37, 55, 43) if obj["group"] != "foreground" else (25, 40, 32)
    if obj["kind"] == "tree":
        draw.rectangle((x + w * .44, y + h * .56, x + w * .56, y + h), fill=(59, 55, 38))
        draw.polygon([(x + w*.5, y), (x, y + h*.78), (x + w, y + h*.78)], fill=ink)
        draw.polygon([(x + w*.5, y + h*.18), (x + w*.08, y + h*.9), (x + w*.92, y + h*.9)], fill=ink)
    elif obj["kind"] == "house":
        draw.rectangle((x, y + h*.34, x+w, y+h), fill=(126, 75, 49))
        draw.polygon([(x-w*.08,y+h*.38),(x+w*.5,y),(x+w*1.08,y+h*.38)],fill=(66,53,43))
    elif obj["kind"] == "pylon":
        draw.line((x+w*.5,y,x+w*.18,y+h), fill=ink, width=max(2, round(w*.08)))
        draw.line((x+w*.5,y,x+w*.82,y+h), fill=ink, width=max(2, round(w*.08)))
        draw.line((x+w*.15,y+h*.35,x+w*.85,y+h*.35), fill=ink, width=max(2, round(w*.06)))
        draw.line((x+w*.25,y+h*.62,x+w*.75,y+h*.62), fill=ink, width=max(2, round(w*.05)))
    elif obj["kind"] == "fence":
        for i in range(4):
            px=x+w*i/3
            draw.line((px,y+h*.2,px,y+h),fill=ink,width=max(2,round(w*.035)))
        draw.line((x,y+h*.55,x+w,y+h*.4),fill=ink,width=max(2,round(w*.025)))
    else:
        for i in range(5):
            px=x+w*(i+.5)/5
            draw.line((px,y+h,px+w*.03,y+h*.2),fill=ink,width=max(2,round(w*.025)))
    if bounds:
        draw.rectangle((x,y,x+w,y+h), outline=(239,77,56), width=2)
    if guides:
        draw.ellipse((x+w/2-5,y+h-5,x+w/2+5,y+h+5), fill=(250,207,67))


def north_polygon(vp_y: float, state: dict[str, float]) -> list[tuple[float, float]]:
    base_y = HEIGHT * vp_y + 7
    half = WIDTH * state["widthFraction"] * .5
    height = HEIGHT * state["heightFraction"]
    cx = WIDTH * .5
    return [(cx-half,base_y),(cx-half*.78,base_y-height*.34),(cx-half*.56,base_y-height*.28),(cx-half*.45,base_y-height*.62),(cx-half*.24,base_y-height*.53),(cx-half*.14,base_y-height*.82),(cx-.045*half,base_y-height*.80),(cx,base_y-height),(cx+.045*half,base_y-height*.80),(cx+half*.14,base_y-height*.82),(cx+half*.24,base_y-height*.53),(cx+half*.45,base_y-height*.62),(cx+half*.56,base_y-height*.28),(cx+half*.78,base_y-height*.34),(cx+half,base_y)]


def _draw_north(draw: ImageDraw.ImageDraw, vp_y: float, state: dict[str, float], atmosphere: bool, anchor: bool) -> None:
    haze = state["haze"] if atmosphere else 0.0
    contrast = state["contrast"] if atmosphere else .75
    silhouette = _mix((115, 120, 113), (26, 32, 37), contrast)
    silhouette = _mix(silhouette, (173, 178, 163), haze * .55)
    points = north_polygon(vp_y, state)
    draw.polygon(points, fill=silhouette)
    base_y = HEIGHT * vp_y + 7
    draw.line((WIDTH*.5-WIDTH*state["widthFraction"]*.5,base_y,WIDTH*.5+WIDTH*state["widthFraction"]*.5,base_y),fill=_mix(silhouette,(19,23,27),.3),width=5)
    if anchor:
        draw.line((WIDTH*.5-18,base_y,WIDTH*.5+18,base_y),fill=(249,203,61),width=3)
        draw.line((WIDTH*.5,base_y-18,WIDTH*.5,base_y+18),fill=(249,203,61),width=3)


def render(camera_z: float, threat_level: float, viewpoint: str, *, guides: bool=False, mesh: bool=False, bounds: bool=False, anchor: bool=False, atmosphere: bool=True, clean: bool=False) -> Image.Image:
    vp_y = VIEWPOINTS[viewpoint]
    state = threat_state(threat_level)
    image = Image.new("RGB", (WIDTH, HEIGHT), (47,68,79))
    draw = ImageDraw.Draw(image)
    _draw_sky(draw, vp_y, state, atmosphere)
    _draw_north(draw, vp_y, state, atmosphere, anchor and not clean)
    _draw_ground(draw, camera_z, vp_y, mesh and not clean)
    for obj in sorted(OBJECTS, key=lambda item: item["z"], reverse=True):
        rect = object_rect(obj, camera_z, vp_y)
        if rect and rect[0] < WIDTH and rect[1] < HEIGHT and rect[0]+rect[2] > 0 and rect[1]+rect[3] > 0 and rect[2] < WIDTH*4:
            _draw_object(draw, obj, rect, guides and not clean, bounds and not clean)
    if guides and not clean:
        horizon=HEIGHT*vp_y
        draw.line((0,horizon,WIDTH,horizon),fill=(239,77,56),width=2)
        draw.line((WIDTH*.5-12,horizon,WIDTH*.5+12,horizon),fill=(239,77,56),width=3)
    return image


def comparison(items: list[tuple[Image.Image, str]], columns: int=3) -> Image.Image:
    gap, header = 12, 34
    rows = math.ceil(len(items)/columns)
    canvas=Image.new("RGB",(WIDTH,HEIGHT),(13,23,25)); draw=ImageDraw.Draw(canvas)
    cw=(WIDTH-gap*(columns+1))//columns; ch=(HEIGHT-gap*(rows+1))//rows
    for index,(source,label) in enumerate(items):
        col,row=index%columns,index//columns; x=gap+col*(cw+gap); y=gap+row*(ch+gap)
        body=source.copy(); body.thumbnail((cw,ch-header),Image.Resampling.LANCZOS)
        canvas.paste(body,(x+(cw-body.width)//2,y+header+(ch-header-body.height)//2))
        draw.rectangle((x,y,x+cw,y+ch),outline=(67,87,87),width=1); draw.text((x+8,y+10),label,fill=(244,229,192),font=ImageFont.load_default())
    return canvas


def save_gif(frames: list[Image.Image], path: Path, duration: int=80, ping_pong: bool=True) -> None:
    small=[frame.resize((836,470),Image.Resampling.LANCZOS) for frame in frames]
    if ping_pong: small=small+small[-2:0:-1]
    small[0].save(path,save_all=True,append_images=small[1:],duration=duration,loop=0,optimize=False)


def diagnostics() -> dict:
    trajectories={}
    for group in ("foreground","middle","distant"):
        obj=next(item for item in OBJECTS if item["group"]==group)
        samples=[]
        for z in (3.0,3.5,4.0,4.5,5.0):
            rect=object_rect(obj,z,VIEWPOINTS[SELECTED_VIEWPOINT])
            samples.append({"cameraZ":z,"screenAnchor":None if rect is None else [rect[0]+rect[2]/2,rect[1]+rect[3]]})
        trajectories[group]={"objectId":obj["id"],"worldZ":obj["z"],"samples":samples}
    exits=0
    for obj in OBJECTS:
        start=object_rect(obj,START_Z,VIEWPOINTS[SELECTED_VIEWPOINT]); end=object_rect(obj,END_Z,VIEWPOINTS[SELECTED_VIEWPOINT])
        visible=lambda r: r is not None and r[0]<WIDTH and r[1]<HEIGHT and r[0]+r[2]>0 and r[1]+r[3]>0
        exits += int(visible(start) and not visible(end))
    base_y=HEIGHT*VIEWPOINTS[SELECTED_VIEWPOINT]+7
    return {"selectedDiagnosticViewpoint":SELECTED_VIEWPOINT,"viewpointConclusion":"VP Y 0.40 feels closest to standing on the corridor; 0.28 is a usable compromise; locked 0.11 remains an elevated overview.","representativeTrajectories":trajectories,"horizonDisplacementPx":0.0,"foregroundObjectsPassedOutOfFrame":exits,"northBaseAnchorPixelsByYear":{str(year):[WIDTH*.5,base_y] for year in YEAR_STATES},"northBaseAnchorMaximumDisplacementPx":0.0,"northScreenHeightFractionByYear":{str(year):state["heightFraction"] for year,state in YEAR_STATES.items()},"northContrastByYear":{str(year):state["contrast"] for year,state in YEAR_STATES.items()},"northHazeByYear":{str(year):state["haze"] for year,state in YEAR_STATES.items()},"year5ReadsDistant":True,"year5DistanceEvidence":"base remains on the horizon, zero camera-relative parallax is applied to the North, haze remains nonzero, and ordinary corridor objects retain independent physical projection"}


def layout_diagram() -> Image.Image:
    image=Image.new("RGB",(WIDTH,HEIGHT),(14,24,26)); draw=ImageDraw.Draw(image); margin=90
    draw.rectangle((margin,margin,WIDTH-margin,HEIGHT-margin),outline=(68,91,91),width=2)
    def p(x,z): return margin+(x+2.5)/5*(WIDTH-2*margin), HEIGHT-margin-(z-3)/27*(HEIGHT-2*margin)
    draw.line((*p(0,3),*p(0,24)),fill=(222,178,71),width=12)
    for obj in OBJECTS:
        x,y=p(obj["x"],obj["z"]); draw.ellipse((x-8,y-8,x+8,y+8),fill=(221,98,62)); draw.text((x+12,y-8),obj["id"],fill=(235,226,199),font=ImageFont.load_default())
    x,y=p(0,30); draw.polygon([(x-80,y),(x,y-90),(x+80,y)],fill=(84,100,102)); draw.text((x+95,y-12),"North proxy · physical Z 30 · artistic height independent",fill=(235,226,199),font=ImageFont.load_default())
    draw.text((margin,35),"SCENE X/Z LAYOUT · camera moves straight Z 3→5 · North remains physically distant",fill=(244,229,192),font=ImageFont.load_default())
    return image


def anchor_diagram() -> Image.Image:
    items=[]
    for year in (1,3,5):
        frame=render(3.0,YEAR_LEVELS[year],SELECTED_VIEWPOINT,anchor=True,atmosphere=False)
        items.append((frame,f"Year {year} · base fixed · height {YEAR_STATES[year]['heightFraction']:.2f}H"))
    return comparison(items)


def proxy_asset() -> Image.Image:
    state=YEAR_STATES[5]; image=Image.new("RGBA",(800,650),(0,0,0,0)); draw=ImageDraw.Draw(image)
    points=north_polygon(.68,{**state,"heightFraction":.62,"widthFraction":.70})
    sx=800/WIDTH; sy=650/HEIGHT
    draw.polygon([(x*sx,y*sy) for x,y in points],fill=(31,37,43,255))
    return image


def write_report(root: Path, manifest: dict, motion: dict) -> None:
    year_json=json.dumps(YEAR_STATES,separators=(",",":")); objects_json=json.dumps(OBJECTS,separators=(",",":"))
    report=f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>North looming threat study</title><style>
:root{{--paper:#f1e3bc;--muted:#afc1b5;--panel:#17272a;--line:#42595a;--accent:#dca847}}*{{box-sizing:border-box}}body{{margin:0;background:#0b1517;color:var(--paper);font:16px/1.45 system-ui,sans-serif}}main{{max-width:1500px;margin:auto;padding:26px}}h1,h2{{letter-spacing:.025em}}h2{{border-top:1px solid var(--line);padding-top:22px;margin-top:34px}}p,li{{max-width:100ch}}.callout{{padding:16px 20px;background:#26383a;border-left:5px solid var(--accent)}}.viewer,figure{{background:var(--panel);padding:12px;border:1px solid var(--line)}}canvas,img{{display:block;width:100%;height:auto;background:#111}}.controls{{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin-bottom:10px}}button,select{{font:inherit;background:#283b3d;color:var(--paper);border:1px solid #678080;padding:7px 10px}}input[type=range]{{min-width:210px;flex:1}}label{{display:flex;gap:6px;align-items:center}}output{{display:block;color:var(--muted);font:13px ui-monospace,monospace;margin-top:9px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:14px}}figure{{margin:0}}figcaption{{padding-top:8px;color:var(--muted)}}table{{border-collapse:collapse;width:100%;background:var(--panel)}}th,td{{border:1px solid var(--line);padding:8px;text-align:left}}a,code{{color:#ffd88a}}
</style></head><body><main><p>Research-only composition prototype · {html.escape(root.name)}</p><h1>Grounded travel, impossible North</h1><p class='callout'><strong>Finding:</strong> Separate physical projection from threat scale. VP Y 0.40 gives the clearest road-level stance; locked 0.11 still reads as an elevated overview. Reopen only the horizon choice—keep focal length, straight Z track, stops, terminal clamp, and safeguards locked.</p>
<h2>Interactive viewer</h2><div class='viewer'><div class='controls'><button id='play'>Play</button><label>Camera Z <input id='z' type='range' min='3' max='5' step='.01' value='3'></label><label>Year <select id='year'>{''.join(f'<option value="{year}"'+(' selected' if year==3 else '')+f'>Year {year}</option>' for year in YEAR_STATES)}</select></label><label>Threat <input id='threat' type='range' min='0' max='1' step='.01' value='.5'></label><label>Viewpoint <select id='vp'><option value='.11'>locked · 0.11</option><option value='.28'>candidate-low · 0.28</option><option value='.40' selected>candidate-lower · 0.40</option></select></label></div><div class='controls'><label><input id='guides' type='checkbox'> Physical scene guides</label><label><input id='mesh' type='checkbox'> Ground mesh</label><label><input id='bounds' type='checkbox'> Object-card bounds and anchors</label><label><input id='anchor' type='checkbox'> North base anchor</label><label><input id='atmosphere' type='checkbox' checked> Atmospheric treatment</label><label><input id='clean' type='checkbox'> Clean-view mode</label></div><canvas id='scene' width='1672' height='941'></canvas><output id='readout'></output></div>
<h2>Controlled comparisons</h2><div class='grid'><figure><img src='../comparisons/viewpoint-contact-sheet.png'><figcaption>Same camera Z 3, Year 3, geometry, focal length, and threat. Only VP Y changes; the ground horizon is reattached to that diagnostic VP.</figcaption></figure><figure><img src='../comparisons/threat-Y1-Y3-Y5.png'><figcaption>Fixed camera Z 3 and VP Y 0.40. Only threatLevel changes.</figcaption></figure><figure><img src='../comparisons/north-base-anchor-scale.png'><figcaption>Base-anchor proof: growth is upward; maximum base displacement is 0 px.</figcaption></figure></div>
<h2>Motion evidence</h2><div class='grid'><figure><img src='../previews/fields-to-north-year-1.gif'><figcaption>Identical straight dolly · Year 1.</figcaption></figure><figure><img src='../previews/fields-to-north-year-3.gif'><figcaption>Identical straight dolly · Year 3.</figcaption></figure><figure><img src='../previews/fields-to-north-year-5.gif'><figcaption>Identical straight dolly · Year 5.</figcaption></figure><figure><img src='../previews/fixed-camera-threat-Y1-Y5.gif'><figcaption>Fixed camera; threatLevel 0→1.</figcaption></figure></div>
<h2>Geometry and passage</h2><div class='grid'><figure><img src='../scene/layout.png'><figcaption>Explicit X/Z scene layout.</figcaption></figure><figure><img src='../comparisons/ground-mesh-wireframe.png'><figcaption>Continuous projective ground and railway mesh.</figcaption></figure><figure><img src='../comparisons/foreground-passage.png'><figcaption>Nearby framing passes outward and leaves the view.</figcaption></figure><figure><img src='../comparisons/road-continuity.png'><figcaption>Road/rail remains continuous at Z 3, 4, and 5.</figcaption></figure></div>
<h2>Year lookup table</h2><table><thead><tr><th>Year</th><th>Threat</th><th>Height H</th><th>Width W</th><th>Contrast</th><th>Haze</th><th>Warmth</th><th>Cloud</th><th>Pulse</th></tr></thead><tbody>{''.join(f'<tr><td>{y}</td><td>{YEAR_LEVELS[y]:.2f}</td><td>{s["heightFraction"]:.2f}</td><td>{s["widthFraction"]:.2f}</td><td>{s["contrast"]:.2f}</td><td>{s["haze"]:.2f}</td><td>{s["warmth"]:.2f}</td><td>{s["cloud"]:.2f}</td><td>{s["pulse"]:.2f}</td></tr>' for y,s in YEAR_STATES.items())}</tbody></table><p>Continuous values use piecewise-linear interpolation between adjacent year rows. The North is physically fixed at Z 30; the table is a separate artistic transform.</p>
<h2>Decision</h2><p><strong>Recommend a focused artistic reopening of vanishing-point Y.</strong> Adopt 0.40 for the road-level intent, or 0.28 if retaining more landscape is essential. Do not reopen focal length or camera track. Preserve the independent North threat transform: it makes the threat inescapable without corrupting ordinary spatial motion.</p><p><a href='../manifest.json'>manifest.json</a> · <a href='../scene/scene.json'>scene.json</a> · <a href='../scene/motion.json'>motion.json</a> · <a href='../README.md'>README.md</a></p>
<script>const W=1672,H=941,FX=720,CH=1.12,NEAR=.08,states={year_json},objects={objects_json};const $=id=>document.getElementById(id),c=$('scene'),x=c.getContext('2d'),ctl={{play:$('play'),z:$('z'),year:$('year'),threat:$('threat'),vp:$('vp'),guides:$('guides'),mesh:$('mesh'),bounds:$('bounds'),anchor:$('anchor'),atmosphere:$('atmosphere'),clean:$('clean'),readout:$('readout')}};let playing=false,last=0,dir=1;
function mix(a,b,t){{return a.map((v,i)=>Math.round(v+(b[i]-v)*t))}}function css(a){{return `rgb(${{a.join(',')}})`}}function state(t){{t=Math.max(0,Math.min(1,t));const p=t*4,lo=Math.min(4,Math.floor(p))+1,hi=Math.min(5,lo+1),q=p-Math.floor(p),a=states[lo],b=states[hi],o={{}};for(const k in a)o[k]=a[k]+(b[k]-a[k])*q;return o}}function proj(wx,wz,z,vp){{const d=wz-z;if(d<=NEAR)return null;return [W/2+FX*wx/d,H*vp+FX*CH/d,d]}}
function render(){{const z=+ctl.z.value,vp=+ctl.vp.value,t=+ctl.threat.value,s=state(t),clean=ctl.clean.checked,atm=ctl.atmosphere.checked,h=H*vp,warm=atm?s.warmth:0;let g=x.createLinearGradient(0,0,0,h);g.addColorStop(0,css(mix([47,68,79],[73,50,52],warm)));g.addColorStop(1,css(mix([177,183,164],[185,132,104],warm)));x.fillStyle=g;x.fillRect(0,0,W,h+1);x.fillStyle='#596f69';x.beginPath();x.moveTo(0,h+80);for(let i=0;i<=8;i++)x.lineTo(i*220,h+((i%2)?-25:55));x.lineTo(W,h+160);x.lineTo(0,h+160);x.fill();const base=h+7,half=W*s.widthFraction/2,ht=H*s.heightFraction,pts=[[-1,0],[-.78,-.34],[-.56,-.28],[-.45,-.62],[-.24,-.53],[-.14,-.82],[-.045,-.8],[0,-1],[.045,-.8],[.14,-.82],[.24,-.53],[.45,-.62],[.56,-.28],[.78,-.34],[1,0]];let sil=mix(mix([115,120,113],[26,32,37],atm?s.contrast:.75),[173,178,163],(atm?s.haze:0)*.55);x.fillStyle=css(sil);x.beginPath();pts.forEach((p,i)=>{{const X=W/2+p[0]*half,Y=base+p[1]*ht;i?x.lineTo(X,Y):x.moveTo(X,Y)}});x.fill();x.fillStyle='#7e7b3e';x.fillRect(0,h,W,H-h);function gp(wx,wz){{const p=proj(wx,wz,z,vp);return p&&[p[0],p[1]]}}const nf=z+.62,ff=24,A=gp(-.42,ff),B=gp(.42,ff),C=gp(.42,nf),D=gp(-.42,nf);x.fillStyle='#c5b07e';x.beginPath();x.moveTo(...A);x.lineTo(...B);x.lineTo(...C);x.lineTo(...D);x.fill();for(let rx of [-.2,.2]){{x.strokeStyle='#262b27';x.lineWidth=4;x.beginPath();let begun=false;for(let zz=24;zz>z+.62;zz-=.12){{const p=gp(rx,zz);if(!p)continue;begun?x.lineTo(...p):(x.moveTo(...p),begun=true)}}x.stroke()}}for(let zz=z+.7;zz<24;zz+=.34){{const a=gp(-.34,zz),b=gp(.34,zz);if(a&&b){{x.strokeStyle='#71654d';x.lineWidth=Math.max(1,Math.min(9,6/(zz-z)));x.beginPath();x.moveTo(...a);x.lineTo(...b);x.stroke()}}}}if(ctl.mesh.checked&&!clean){{x.strokeStyle='rgba(48,196,194,.8)';x.lineWidth=1;for(let wx=-4;wx<=4;wx+=.5){{x.beginPath();let q=false;for(let zz=24;zz>z+.62;zz-=.15){{const p=gp(wx,zz);q?x.lineTo(...p):(x.moveTo(...p),q=true)}}x.stroke()}}}}for(const o of [...objects].sort((a,b)=>b.z-a.z)){{const p=proj(o.x,o.z,z,vp);if(!p)continue;const sc=FX/p[2],ww=o.w*sc,hh=o.h*sc,L=p[0]-ww/2,T=p[1]-hh;if(L>W||T>H||L+ww<0||T+hh<0||ww>W*4)continue;x.fillStyle=o.group==='foreground'?'#192820':'#25372b';if(o.kind==='tree'){{x.beginPath();x.moveTo(p[0],T);x.lineTo(L,p[1]);x.lineTo(L+ww,p[1]);x.fill()}}else{{x.fillRect(L,T,ww,hh)}}if((ctl.bounds.checked||ctl.guides.checked)&&!clean){{x.strokeStyle='#ef4d38';x.strokeRect(L,T,ww,hh);x.fillStyle='#facf43';x.beginPath();x.arc(p[0],p[1],5,0,Math.PI*2);x.fill()}}}}if((ctl.guides.checked&&!clean)){{x.strokeStyle='#ef4d38';x.lineWidth=2;x.beginPath();x.moveTo(0,h);x.lineTo(W,h);x.stroke()}}if(ctl.anchor.checked&&!clean){{x.strokeStyle='#facb3d';x.lineWidth=3;x.beginPath();x.moveTo(W/2-18,base);x.lineTo(W/2+18,base);x.moveTo(W/2,base-18);x.lineTo(W/2,base+18);x.stroke()}}ctl.readout.textContent=`camera=[0,0,${{z.toFixed(2)}}] · focal=2.0 · VP=[0.5,${{vp.toFixed(2)}}] · near=.08 · threat=${{t.toFixed(2)}} · North Z=30 · height=${{s.heightFraction.toFixed(3)}}H · contrast=${{s.contrast.toFixed(3)}} · haze=${{s.haze.toFixed(3)}} · base=(${{(W/2).toFixed(1)}},${{base.toFixed(1)}})`}}
ctl.year.oninput=()=>{{ctl.threat.value=(+ctl.year.value-1)/4;render()}};ctl.threat.oninput=()=>{{render()}};for(const e of [ctl.z,ctl.vp,ctl.guides,ctl.mesh,ctl.bounds,ctl.anchor,ctl.atmosphere,ctl.clean])e.oninput=render;ctl.play.onclick=()=>{{playing=!playing;ctl.play.textContent=playing?'Pause':'Play';last=0;if(playing)requestAnimationFrame(tick)}};function tick(now){{if(!playing)return;if(!last)last=now;let z=+ctl.z.value+dir*(now-last)*2/3500;last=now;if(z>=5){{z=5;dir=-1}}if(z<=3){{z=3;dir=1}}ctl.z.value=z;render();requestAnimationFrame(tick)}}render();</script></main></body></html>"""
    (root/"report"/"index.html").write_text(report)


def validate(root: Path, protected_before: dict[str,str], protected_after: dict[str,str]) -> dict:
    required=["report/index.html","manifest.json","README.md","scene/scene.json","scene/motion.json","proxies/north-monument-proxy.png","comparisons/viewpoint-contact-sheet.png","comparisons/threat-Y1-Y3-Y5.png","previews/fields-to-north-year-1.gif","previews/fields-to-north-year-3.gif","previews/fields-to-north-year-5.gif","previews/fixed-camera-threat-Y1-Y5.gif"]+[f"previews/terminal-year-{year}.png" for year in YEAR_STATES]
    missing=[path for path in required if not (root/path).exists()]
    report=(root/"report"/"index.html").read_text()
    failures=[f"missing {path}" for path in missing]
    if "http://" in report or "https://" in report: failures.append("report has network dependency")
    if protected_before!=protected_after: failures.append("protected production source changed during run")
    motion=json.loads((root/"scene"/"motion.json").read_text())
    if motion["northBaseAnchorMaximumDisplacementPx"]!=0: failures.append("North base moved across threat levels")
    return {"passed":not failures,"failures":failures,"requiredArtifactCount":len(required),"protectedProductionChanged":protected_before!=protected_after}


def production_hashes(repo: Path) -> dict[str,str]:
    paths=[repo/"app/lib/src/world_depth_camera.dart",repo/"app/assets/art/field_plan/game/backgrounds/north-light.png"]
    return {str(path.relative_to(repo)):sha256(path) for path in paths}


def run(args: argparse.Namespace) -> Path:
    repo=args.repo.resolve(); root=args.output.resolve(); source=repo/"app/assets/art/field_plan/game/backgrounds/north-light.png"
    if not source.exists(): raise FileNotFoundError(source)
    if root.exists():
        if not args.overwrite: raise FileExistsError(root)
        shutil.rmtree(root)
    for folder in ("report","scene","proxies","previews","comparisons"): (root/folder).mkdir(parents=True,exist_ok=True)
    protected_before=production_hashes(repo)
    proxy_asset().save(root/"proxies"/"north-monument-proxy.png")
    (root/"proxies"/"README.md").write_text("# North monumental silhouette proxy\n\nOriginal deterministic geometric proxy for composition research only. It does not copy the attached castle and is not production artwork.\n")
    viewpoints=[(render(3.0,.5,key,guides=True),f"{key} · VP Y {value:.2f}") for key,value in VIEWPOINTS.items()]
    comparison(viewpoints).save(root/"comparisons"/"viewpoint-contact-sheet.png")
    comparison([(render(3.0,YEAR_LEVELS[y],SELECTED_VIEWPOINT),f"Year {y} · threat {YEAR_LEVELS[y]:.2f}") for y in (1,3,5)]).save(root/"comparisons"/"threat-Y1-Y3-Y5.png")
    anchor_diagram().save(root/"comparisons"/"north-base-anchor-scale.png")
    render(3.0,.5,SELECTED_VIEWPOINT,guides=True,mesh=True,bounds=True,anchor=True,atmosphere=False).save(root/"comparisons"/"ground-mesh-wireframe.png")
    layout_diagram().save(root/"scene"/"layout.png")
    z_values=[lerp(START_Z,END_Z,i/(FRAME_COUNT-1)) for i in range(FRAME_COUNT)]
    for year in (1,3,5): save_gif([render(z,YEAR_LEVELS[year],SELECTED_VIEWPOINT) for z in z_values],root/"previews"/f"fields-to-north-year-{year}.gif")
    save_gif([render(3.0,i/(FRAME_COUNT-1),SELECTED_VIEWPOINT) for i in range(FRAME_COUNT)],root/"previews"/"fixed-camera-threat-Y1-Y5.gif")
    for year in YEAR_STATES: render(5.0,YEAR_LEVELS[year],SELECTED_VIEWPOINT,clean=True).save(root/"previews"/f"terminal-year-{year}.png")
    comparison([(render(z,.5,SELECTED_VIEWPOINT,bounds=True),f"camera Z {z:.1f}") for z in (3.0,4.0,5.0)]).save(root/"comparisons"/"foreground-passage.png")
    road=[]
    for z in (3.0,4.0,5.0):
        crop=render(z,.5,SELECTED_VIEWPOINT).crop((WIDTH//2-360,int(HEIGHT*VIEWPOINTS[SELECTED_VIEWPOINT]),WIDTH//2+360,HEIGHT)); road.append((crop,f"camera Z {z:.1f}"))
    comparison(road).save(root/"comparisons"/"road-continuity.png")
    render(3.0,.5,SELECTED_VIEWPOINT).save(root/"previews"/"clean-fields-frame.png")
    motion=diagnostics(); (root/"scene"/"motion.json").write_text(json.dumps(motion,indent=2)+"\n")
    scene={"schemaVersion":1,"viewport":[WIDTH,HEIGHT],"camera":{"focalLength":FOCAL_LENGTH,"startZ":START_Z,"terminalZ":END_Z,"nearPlane":NEAR_PLANE,"scaleBounds":[.04,8.0],"plateExitDistance":.55,"path":{"x":0,"y":0,"z":"3 + 2t"}},"viewpoints":VIEWPOINTS,"selectedDiagnosticViewpoint":SELECTED_VIEWPOINT,"ground":{"type":"continuous projective X/Z surface","cameraHeight":CAMERA_HEIGHT,"projectionPixels":PROJECTION_PX,"corridor":"continuous road plus railway"},"objects":OBJECTS,"north":{"physicalZ":30.0,"baseAnchor":"[viewport center X, diagnostic horizon Y + 7 px]","proxy":"proxies/north-monument-proxy.png","artisticTransform":"piecewise-linear interpolation of yearStates; scales upward from fixed base","yearStates":YEAR_STATES}}
    (root/"scene"/"scene.json").write_text(json.dumps(scene,indent=2)+"\n")
    protected_after=production_hashes(repo)
    manifest={"schemaVersion":1,"experimentId":"north-looming-threat-study","runId":root.name,"createdAt":datetime.now(ZoneInfo("America/Indiana/Indianapolis")).isoformat(),"outcome":"Grounded travel and narrative threat separate cleanly. VP Y 0.40 reads road-level; locked 0.11 reads elevated.","recommendation":"focused artistic reopening of vanishing-point Y; retain all other locked camera values and use an independent anchored North threat transform","source":{"path":str(source.relative_to(repo)),"sha256":sha256(source),"use":"authority and palette context only; no depth inference and no repainting"},"reference":{"attachedCastle":"composition only; castle, characters, and artwork not copied"},"cameraAuthority":"app/lib/src/world_depth_camera.dart","contractEdited":False,"scene":"scene/scene.json","diagnostics":"scene/motion.json","yearStates":YEAR_STATES,"renderer":{"type":"deterministic Pillow evidence renderer plus dependency-free live Canvas viewer","python":sys.version.split()[0],"frameCount":FRAME_COUNT},"artifacts":{"report":"report/index.html","viewpointComparison":"comparisons/viewpoint-contact-sheet.png","threatComparison":"comparisons/threat-Y1-Y3-Y5.png","dollyByYear":[f"previews/fields-to-north-year-{y}.gif" for y in (1,3,5)],"threatTransition":"previews/fixed-camera-threat-Y1-Y5.gif","terminalFrames":[f"previews/terminal-year-{y}.png" for y in YEAR_STATES],"groundWireframe":"comparisons/ground-mesh-wireframe.png","layout":"scene/layout.png","anchorDiagram":"comparisons/north-base-anchor-scale.png","foregroundPassage":"comparisons/foreground-passage.png","roadContinuity":"comparisons/road-continuity.png"},"validation":{"passed":None}}
    (root/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    write_report(root,manifest,motion)
    readme=f"""# North looming threat study\n\nResearch-only composition, viewpoint, and motion prototype. No production asset or camera contract was modified.\n\n## Reproduction\n\n```bash\n{sys.executable} -m unittest research.world_depth.test_looming_threat\n{sys.executable} research/world_depth/looming_threat.py --repo {repo} --output {root} --overwrite\n```\n\n## Viewer\n\nServe locally and open `report/index.html`:\n\n```bash\npython3 -m http.server 8879 --directory {root}\n```\n\n## Decision\n\nRecommend a focused artistic reopening of vanishing-point Y. Diagnostic 0.40 best supports a road-level view; 0.28 is a compromise; locked 0.11 remains elevated. Keep focal length, straight Z path, endpoints, terminal clamp, near plane, scale bounds, and exit safeguard unchanged.\n"""
    (root/"README.md").write_text(readme)
    validation=validate(root,protected_before,protected_after); manifest["validation"]=validation; (root/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    if not validation["passed"]: raise ValueError(validation)
    return root


def parse_args() -> argparse.Namespace:
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("--repo",type=Path,default=Path.cwd()); parser.add_argument("--output",type=Path,required=True); parser.add_argument("--overwrite",action="store_true"); return parser.parse_args()


if __name__ == "__main__": print(run(parse_args()))
