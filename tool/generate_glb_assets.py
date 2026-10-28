#!/usr/bin/env python3
"""Generate original, brand-free industrial GLB assets for ELEC LAB.

The generator reads dimensions and terminal coordinates from ComponentCatalog so
GLB hardware and the electrical model share one source of truth. No downloaded
models, textures, screenshots or manufacturer CAD files are used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
SOURCE_ROOT = ROOT / "tool" / "asset_pack" / "models"

# User-supplied starter GLBs are real geometry inputs for preview/detailed LODs.
# Board LOD stays lighter and is generated from the same calibrated catalog.
SOURCE_MAP = {
    "dcSupply": ["psu_dc"], "acSupply": ["psu_single"],
    "threePhaseSupply": ["psu_three"], "circuitBreaker": ["mcb"],
    "differentialBreaker": ["rcd"], "motorBreaker": ["motor_breaker"],
    "contactor": ["contactor"], "thermalRelay": ["thermal_relay"],
    "auxiliaryRelay": ["aux_relay"], "motor3Phase": ["motor_3ph"],
    "motor1Phase": ["motor_1ph"], "pushButtonNO": ["pushbutton_green"],
    "pushButtonNC": ["pushbutton_red"], "emergencyStop": ["emergency_stop"],
    "selectorSwitch": ["selector"], "indicator": ["pilot_red", "pilot_green", "pilot_amber"],
    "timer": ["timer_on"], "timerOffDelay": ["timer_off"],
    "terminalBlock": ["terminal_block"], "fuse": ["fuse_holder"],
    "transformer": ["transformer"], "limitSwitch": ["limit_switch"],
    "sensor": ["sensor"], "voltmeter": ["voltmeter"], "ammeter": ["ammeter"],
    "digitalCounter": ["digital_meter"],
}
CURRENT_SOURCE_INFO = []
CURRENT_SOURCE_STEMS = []

C = {
    "ivory": 0xFFE2E4DF, "polymer": 0xFFC5CBD0, "white": 0xFFF2F3EF,
    "dark": 0xFF242C33, "black": 0xFF10161B, "rubber": 0xFF171D22,
    "metal": 0xFF9EAAB2, "chrome": 0xFFD1D9DE, "brass": 0xFFC49A4A,
    "copper": 0xFFB96B3F, "blue": 0xFF167BC1, "motorBlue": 0xFF245C88,
    "cyan": 0xFF35C8D4, "green": 0xFF28A874, "statusLens": 0xFFE53935,
    "red": 0xFFD63A35, "yellow": 0xFFF2C230, "orange": 0xFFD98D32,
    "glass": 0xFF71858E, "label": 0xFFE9ECE8, "ink": 0xFF25323B,
    "screen": 0xFF102A31, "screenInk": 0xFF73E0C0, "earth": 0xFF7CA33B,
}

FONT = {
"A":["01110","10001","10001","11111","10001","10001","10001"],
"B":["11110","10001","10001","11110","10001","10001","11110"],
"C":["01111","10000","10000","10000","10000","10000","01111"],
"D":["11110","10001","10001","10001","10001","10001","11110"],
"E":["11111","10000","10000","11110","10000","10000","11111"],
"F":["11111","10000","10000","11110","10000","10000","10000"],
"G":["01111","10000","10000","10111","10001","10001","01111"],
"H":["10001","10001","10001","11111","10001","10001","10001"],
"I":["11111","00100","00100","00100","00100","00100","11111"],
"J":["00111","00010","00010","00010","10010","10010","01100"],
"K":["10001","10010","10100","11000","10100","10010","10001"],
"L":["10000","10000","10000","10000","10000","10000","11111"],
"M":["10001","11011","10101","10101","10001","10001","10001"],
"N":["10001","11001","10101","10011","10001","10001","10001"],
"O":["01110","10001","10001","10001","10001","10001","01110"],
"P":["11110","10001","10001","11110","10000","10000","10000"],
"Q":["01110","10001","10001","10001","10101","10010","01101"],
"R":["11110","10001","10001","11110","10100","10010","10001"],
"S":["01111","10000","10000","01110","00001","00001","11110"],
"T":["11111","00100","00100","00100","00100","00100","00100"],
"U":["10001","10001","10001","10001","10001","10001","01110"],
"V":["10001","10001","10001","10001","10001","01010","00100"],
"W":["10001","10001","10001","10101","10101","10101","01010"],
"X":["10001","10001","01010","00100","01010","10001","10001"],
"Y":["10001","10001","01010","00100","00100","00100","00100"],
"Z":["11111","00001","00010","00100","01000","10000","11111"],
"0":["01110","10001","10011","10101","11001","10001","01110"],
"1":["00100","01100","00100","00100","00100","00100","01110"],
"2":["01110","10001","00001","00010","00100","01000","11111"],
"3":["11110","00001","00001","01110","00001","00001","11110"],
"4":["00010","00110","01010","10010","11111","00010","00010"],
"5":["11111","10000","10000","11110","00001","00001","11110"],
"6":["01110","10000","10000","11110","10001","10001","01110"],
"7":["11111","00001","00010","00100","01000","01000","01000"],
"8":["01110","10001","10001","01110","10001","10001","01110"],
"9":["01110","10001","10001","01111","00001","00001","01110"],
"+":["00000","00100","00100","11111","00100","00100","00000"],
"-":["00000","00000","00000","11111","00000","00000","00000"],
"/":["00001","00010","00010","00100","01000","01000","10000"],
".":["00000","00000","00000","00000","00000","00110","00110"],
"~":["00000","00000","01001","10110","00000","00000","00000"],
" ":["00000"]*7,
}


def add(a, b): return tuple(a[i] + b[i] for i in range(3))
def mul(a, k): return tuple(v * k for v in a)


class Mesh:
    def __init__(self, detail):
        self.detail = detail
        self.vertices = []
        self.faces = []
        self.segments = {"board": 8, "preview": 16, "detailed": 28}[detail]

    def shape(self, vertices, faces, material):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(([offset + i for i in face], material) for face in faces)

    def box(self, center, size, material, bevel=0):
        x, y, z = (v / 2 for v in size)
        if bevel <= 0:
            verts = [(center[0]+a*x, center[1]+b*y, center[2]+c*z)
                     for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                   (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
            faces = [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]
            self.shape(verts, faces, material); return
        cut = min(x * .42, y * .42, bevel)
        chamfer = min(z * .42, bevel * .55)
        def outline(ix, iy):
            return [(-ix+cut,-iy),(ix-cut,-iy),(ix,-iy+cut),(ix,iy-cut),
                    (ix-cut,iy),(-ix+cut,iy),(-ix,iy-cut),(-ix,-iy+cut)]
        rings = [(outline(max(.01,x-chamfer),max(.01,y-chamfer)),-z),
                 (outline(x,y),-z+chamfer),(outline(x,y),z-chamfer),
                 (outline(max(.01,x-chamfer),max(.01,y-chamfer)),z)]
        verts = [(center[0]+px,center[1]+py,center[2]+pz)
                 for points,pz in rings for px,py in points]
        faces = []
        for ring in range(3):
            for i in range(8):
                j=(i+1)%8; a=ring*8; b=(ring+1)*8
                faces.append((a+i,a+j,b+j,b+i))
        faces += [tuple(range(7,-1,-1)),tuple(range(24,32))]
        self.shape(verts, faces, material)

    def cylinder(self, center, radius, depth, material, axis="z", radius_top=None, segments=None):
        n = segments or self.segments
        rt = radius if radius_top is None else radius_top
        def point(axial, r, i):
            a=2*math.pi*i/n; u=r*math.cos(a); v=r*math.sin(a)
            local = {"z":(u,v,axial),"x":(axial,u,v),"y":(u,axial,v)}[axis]
            return add(center,local)
        verts=[point(-depth/2,radius,i) for i in range(n)]+[point(depth/2,rt,i) for i in range(n)]
        faces=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        faces += [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        self.shape(verts,faces,material)

    def ring(self, center, outer, inner, depth, material, axis="z"):
        n=self.segments
        def point(axial,r,i):
            a=2*math.pi*i/n; u=r*math.cos(a); v=r*math.sin(a)
            return add(center,{"z":(u,v,axial),"x":(axial,u,v),"y":(u,axial,v)}[axis])
        verts=[]
        for axial,r in [(-depth/2,outer),(depth/2,outer),(-depth/2,inner),(depth/2,inner)]:
            verts += [point(axial,r,i) for i in range(n)]
        faces=[]
        for i in range(n):
            j=(i+1)%n
            faces += [(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),
                      (j,i,2*n+i,2*n+j),(n+i,n+j,3*n+j,3*n+i)]
        self.shape(verts,faces,material)

    def sphere(self, center, radius, material, scale=(1,1,1)):
        n=self.segments; rings=max(4,self.segments//2); verts=[]
        for r in range(rings+1):
            lat=-math.pi/2+math.pi*r/rings
            for i in range(n):
                a=2*math.pi*i/n
                local=(radius*math.cos(lat)*math.cos(a)*scale[0],
                       radius*math.sin(lat)*scale[1],
                       radius*math.cos(lat)*math.sin(a)*scale[2])
                verts.append(add(center,local))
        faces=[]
        for r in range(rings):
            for i in range(n):
                j=(i+1)%n; faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
        self.shape(verts,faces,material)

    def text(self, text, y, z, width, height, material="ink", x=0):
        text=text.upper(); count=max(1,len(text)*6-1)
        px=min(width/count,height/7)
        start=x-(len(text)*6-1)*px/2
        for ci,char in enumerate(text):
            glyph=FONT.get(char,FONT[" "])
            for row,bits in enumerate(glyph):
                col=0
                while col<5:
                    if bits[col]=="0": col+=1; continue
                    end=col
                    while end<5 and bits[end]=="1": end+=1
                    run=end-col
                    cx=start+(ci*6+col+run/2)*px
                    cy=y+(3-row)*px
                    self.box((cx,cy,z),(run*px*.9,px*.82,.009),material)
                    col=end

    def screw(self, x, y, z, radius=.075, material="chrome"):
        self.cylinder((x,y,z),radius,.045,material)
        if self.detail != "board":
            self.box((x,y,z+.027),(radius*1.25,radius*.19,.012),"dark")
            self.box((x,y,z+.028),(radius*.19,radius*1.25,.012),"dark")

    def terminal(self, x, y, z, kind="power", radius=None):
        r=radius or (.075 if self.detail=="board" else .095)
        self.ring((x,y,z),r*1.3,r*.72,.075,"brass" if kind!="earth" else "earth")
        self.cylinder((x,y,z-.015),r*.72,.04,"black")
        self.screw(x,y,z+.055,r*.72)


def read_source_glb(stem):
    """Read the pack's indexed triangle geometry and PBR material names.

    The supplied pack intentionally uses untransformed nodes. Strict bounds and
    component checks here fail generation instead of silently misplacing a mesh.
    """
    path=SOURCE_ROOT/f"{stem}.glb"
    raw=path.read_bytes()
    magic,version,total=struct.unpack_from("<III",raw,0)
    if magic!=0x46546C67 or version!=2 or total!=len(raw):
        raise RuntimeError(f"Invalid source GLB: {path}")
    json_length,json_type=struct.unpack_from("<II",raw,12)
    if json_type!=0x4E4F534A: raise RuntimeError(f"Missing JSON chunk: {path}")
    document=json.loads(raw[20:20+json_length])
    bin_header=20+json_length
    bin_length,bin_type=struct.unpack_from("<II",raw,bin_header)
    if bin_type!=0x004E4942: raise RuntimeError(f"Missing BIN chunk: {path}")
    binary=raw[bin_header+8:bin_header+8+bin_length]
    if len(binary)!=document["buffers"][0]["byteLength"]:
        raise RuntimeError(f"Source buffer mismatch: {path}")

    def accessor(index):
        item=document["accessors"][index]
        view=document["bufferViews"][item["bufferView"]]
        component=item["componentType"]
        fmt,size={5121:("<B",1),5123:("<H",2),5125:("<I",4),5126:("<f",4)}[component]
        dimensions={"SCALAR":1,"VEC3":3}[item["type"]]
        stride=view.get("byteStride",size*dimensions)
        start=view.get("byteOffset",0)+item.get("byteOffset",0)
        values=[]
        for i in range(item["count"]):
            offset=start+i*stride
            values.append(struct.unpack_from("<"+fmt[1]*dimensions,binary,offset))
        return values

    vertices=[]; faces=[]
    for node in document.get("nodes",[]):
        if any(key in node for key in ("matrix","translation","rotation","scale")):
            raise RuntimeError(f"Unexpected source node transform: {path}")
        if "mesh" not in node: continue
        mesh=document["meshes"][node["mesh"]]
        for primitive in mesh["primitives"]:
            if primitive.get("mode",4)!=4: raise RuntimeError(f"Non-triangle source: {path}")
            positions=accessor(primitive["attributes"]["POSITION"])
            indices=accessor(primitive["indices"])
            material=document["materials"][primitive["material"]]
            material_name=material.get("name","polymer")
            offset=len(vertices)
            vertices.extend(tuple(float(v) for v in point) for point in positions)
            for i in range(0,len(indices),3):
                faces.append(([offset+int(indices[i+j][0]) for j in range(3)],material_name))
    if not vertices or not faces: raise RuntimeError(f"Empty source GLB: {path}")
    info={"file":f"models/{stem}.glb","sha256":hashlib.sha256(raw).hexdigest(),"bytes":len(raw)}
    return vertices,faces,info


def append_source_geometry(mesh,stem,kind,w,h,d):
    vertices,faces,info=read_source_glb(stem)
    lo=[min(v[i] for v in vertices) for i in range(3)]
    hi=[max(v[i] for v in vertices) for i in range(3)]
    spans=[max(1e-9,hi[i]-lo[i]) for i in range(3)]
    scale=min(w/spans[0],h/spans[1],d/spans[2])*.94
    center=[(lo[i]+hi[i])/2 for i in range(3)]
    offset=len(mesh.vertices)
    mesh.vertices.extend(tuple((v[i]-center[i])*scale-(d*.06 if i==2 else 0) for i in range(3)) for v in vertices)
    material_map={"light":"ivory","body":"polymer","amber":"yellow"}
    for indices,material in faces:
        mapped=material_map.get(material,material if material in C else "polymer")
        if kind=="indicator" and material in {"red","green","amber","yellow"}:
            mapped="statusLens"
        mesh.faces.append(([offset+i for i in indices],mapped))
    return info


def source_refinements(mesh,kind,spec,w,h,d,detail):
    """Add calibrated connection hardware and brand-free technical details."""
    front=d*.55
    if kind in {"motor3Phase","motor1Phase","motor6Terminal"}:
        # Additional cooling fins and a six-screw terminal box on the new motor.
        fins=8 if detail=="preview" else 14
        for i in range(fins):
            a=2*math.pi*i/fins
            mesh.box((0,math.cos(a)*h*.31,math.sin(a)*h*.31),(w*.5,.035,.035),"motorBlue" if kind!="motor1Phase" else "polymer",.008)
        mesh.box((0,h*.34,d*.22),(w*.43,h*.28,d*.45),"dark",.03)
        if kind=="motor6Terminal":
            labels(mesh,"U1 V1 W1","U2 V2 W2",h*.34,d*.48,w*.4,detail)
    elif kind=="cableSegment":
        for side in [-1,1]:
            mesh.cylinder((side*w*.46,0,d*.12),h*.13,w*.08,"copper",axis="x")
            mesh.ring((side*w*.5,0,d*.12),h*.16,h*.1,w*.04,"brass",axis="x")
    elif kind=="currentTransformer":
        labels(mesh,"CT 100/5","S1 S2 2 OHM",-h*.3,front+.12,w*.72,detail)
        for x in [-w*.3,w*.3]: mesh.screw(x,h*.34,front+.1,.06)
    else:
        # Source bodies remain visible; only small vents, screws and a label
        # plate are added instead of hiding them under a duplicate enclosure.
        if detail=="detailed":
            for side in [-1,1]:
                for j in range(4):
                    mesh.box((side*w*.43,(j-1.5)*h*.07,front*.35),(.025,h*.025,d*.28),"dark")
        text={"dcSupply":"DC 24V","acSupply":"1~ 230V","threePhaseSupply":"3~ 400V",
              "circuitBreaker":"MCB","differentialBreaker":"RCBO","motorBreaker":"MPCB",
              "contactor":"K 3P","thermalRelay":"THERMAL","auxiliaryRelay":"RELAY",
              "timer":"ON DELAY","timerOffDelay":"OFF DELAY","digitalCounter":"ENERGY"}.get(kind,kind.upper()[:12])
        labels(mesh,text,"CALIBRATED TERMINALS",-h*.34,front+.08,w*.7,detail)


def depth_for(kind):
    if kind in {"motor3Phase","motor6Terminal","pump","heater3Phase"}: return 1.65
    if kind in {"motor1Phase","fan","solenoidValve"}: return 1.45
    if kind in {"indicator","pushButtonNO","pushButtonNC","emergencyStop","selectorSwitch","rotarySwitch",
                "lightSwitch","twoWaySwitch","intermediateSwitch","bell","buzzer","ledLamp"}: return 1.05
    if kind in {"sensor","limitSwitch","motionSensor","lightSensor","floatSwitch","pressureSwitch","flowSwitch",
                "proximitySensor","capacitiveSensor","photoelectricSensor"}: return .9
    if kind=="cableSegment": return .55
    return .82


def din_shell(m,w,h,d,body="ivory",front="polymer"):
    m.box((0,0,-.05),(w,h,d),body,.09)
    m.box((0,0,-d*.57),(w*.72,h*.15,.16),"dark",.025)
    m.box((0,-h*.46,-d*.67),(w*.42,h*.13,.13),"rubber",.02)
    m.box((0,0,d*.42),(w*.9,h*.79,d*.2),front,.045)
    for side in [-1,1]:
        m.box((side*w*.46,0,d*.12),(.025,h*.72,d*.38),"dark")
        if m.detail=="detailed":
            for j in range(6):
                m.box((side*w*.475,(j-2.5)*h*.095,d*.16),(.018,h*.035,d*.23),"black")
    return d*.56


def terminal_layout(m,kind,spec,d,detail):
    w,h=spec["size"]
    for t in spec["terminals"]:
        x=(t["x"]/w-.5)*w/48
        y=(.5-t["y"]/h)*h/48
        radius=.058 if detail=="board" else .095
        # An insulating terminal well physically joins the screw and wire bore
        # to the enclosure instead of leaving floating hardware in 3D views.
        well_depth=min(.18,d*.18)
        m.cylinder((x,y,d*.72-well_depth/2),radius*1.65,well_depth,"dark" if kind not in {"terminalBlock"} else "orange")
        m.terminal(x,y,d*.72,t["kind"],radius)


def labels(m,primary,secondary,y,z,w,detail):
    m.box((0,y,z-.012),(w,.25 if detail=="detailed" else .2,.025),"label",.012)
    m.text(primary,y,z+.012,w*.9,.14,"ink")
    if detail=="detailed" and secondary:
        m.text(secondary,y-.19,z+.012,w*.82,.09,"ink")


def build_extended(mesh,kind,spec,detail):
    w,h=[v/48 for v in spec["size"]]; d=depth_for(kind); front=d*.56
    model=spec.get("model",kind)
    if model=="motor6":
        mesh.cylinder((0,0,0),h*.3,w*.6,"motorBlue",axis="x")
        for x in [-w*.3,w*.3]: mesh.cylinder((x,0,0),h*.34,.15,"motorBlue",axis="x")
        for i in range(10 if detail=="board" else 18):
            a=2*math.pi*i/(10 if detail=="board" else 18)
            mesh.box((0,math.cos(a)*h*.315,math.sin(a)*h*.315),(w*.56,.045,.045),"motorBlue",.01)
        mesh.cylinder((w*.45,0,0),h*.1,w*.23,"chrome",axis="x")
        mesh.box((0,h*.34,d*.2),(w*.48,h*.32,d*.52),"dark",.035)
        mesh.box((0,h*.34,d*.49),(w*.43,h*.26,.06),"polymer",.02)
        for ix in range(3):
            for iy in [-1,1]: mesh.screw((ix-1)*w*.13,h*.34+iy*h*.07,d*.55,.06,"brass")
        for x in [-w*.22,w*.22]: mesh.box((x,-h*.36,0),(w*.2,h*.15,d*.45),"motorBlue",.02)
        labels(mesh,"M 3~ 6B","U1 V1 W1 / U2 V2 W2",h*.34,d*.55,w*.4,detail)
    elif model in {"mcb2","mcb3","mcb4","rccb","isolator","mccb"}:
        din_shell(mesh,w,h,d,"dark" if model=="mccb" else "ivory","polymer")
        poles={"mcb2":2,"mcb3":3,"mcb4":4,"rccb":2,"isolator":3,"mccb":3}[model]
        if model in {"isolator","mccb"}:
            mesh.box((0,0,front+.1),(w*.75,h*.52,.2),"dark",.04)
            mesh.cylinder((0,0,front+.25),min(w,h)*.23,.16,"red" if model=="isolator" else "black")
            mesh.box((0,min(w,h)*.08,front+.36),(min(w,h)*.11,min(w,h)*.42,.12),"red" if model=="isolator" else "polymer",.02)
        else:
            for p in range(poles):
                x=(p-(poles-1)/2)*w/(poles+1)
                mesh.box((x,h*.03,front+.1),(w/(poles+1)*.72,h*.42,.15),"dark",.025)
                mesh.box((x,h*.04,front+.21),(w/(poles+1)*.4,h*.25,.15),"blue",.025)
            if model=="rccb": mesh.cylinder((w*.32,-h*.25,front+.18),w*.06,.07,"yellow")
        labels(mesh,model.upper(),"SYNCHRONIZED POLES",-h*.34,front+.15,w*.78,detail)
    elif model=="contactor4":
        din_shell(mesh,w,h,d,"dark","ivory")
        for yy in [-h*.37,h*.37]:
            mesh.box((0,yy,front+.06),(w*.98,h*.18,.22),"dark",.03)
            for i in range(4): mesh.screw((i-1.5)*w*.2,yy,front+.2,.07,"brass")
        mesh.box((0,0,front+.18),(w*.68,h*.35,.22),"black",.04)
        mesh.box((0,h*.02,front+.31),(w*.42,h*.12,.05),"glass",.015)
        labels(mesh,"K 4P","A1 A2 13 14 21 22",-h*.24,front+.23,w*.65,detail)
    elif model in {"lightSwitch","twoWay","intermediate"}:
        mesh.box((0,0,-.08),(w*.88,h*.92,d*.68),"ivory",.08)
        mesh.box((0,0,d*.36),(w*.76,h*.78,.16),"white",.05)
        count=2 if model!="lightSwitch" else 1
        for i in range(count):
            x=(i-(count-1)/2)*w*.28
            mesh.box((x,0,d*.52),(w*.2,h*.46,.16),"polymer",.025)
            mesh.box((x,h*.08,d*.63),(w*.12,h*.28,.1),"white",.02)
        for x in [-w*.31,w*.31]: mesh.screw(x,h*.34,d*.47,.05)
        labels(mesh,"I" if model=="lightSwitch" else "2 WAY" if model=="twoWay" else "CROSS",model.upper(),-h*.32,d*.52,w*.65,detail)
    elif model in {"impulse","staircase","phaseRelay","thermostat"}:
        din_shell(mesh,w,h,d)
        if model=="impulse":
            mesh.box((0,h*.08,front+.12),(w*.68,h*.4,.15),"glass",.03)
            mesh.cylinder((0,h*.08,front+.24),w*.15,h*.32,"copper",axis="y")
            mesh.sphere((w*.25,-h*.22,front+.18),w*.055,"green")
        elif model=="staircase":
            mesh.box((0,h*.12,front+.12),(w*.7,h*.25,.08),"screen",.02)
            mesh.text("60 S",h*.12,front+.18,w*.55,h*.14,"screenInk")
            for i in range(3): mesh.box(((i-1)*w*.15,-h*.15+i*h*.04,front+.15),(w*.12,.035,.04),"dark")
            mesh.cylinder((0,-h*.3,front+.15),w*.11,.08,"blue")
        elif model=="phaseRelay":
            for i,color in enumerate(["red","yellow","blue"]):
                mesh.sphere(((i-1)*w*.22,h*.15,front+.16),w*.07,color)
            mesh.cylinder((0,-h*.12,front+.15),w*.16,.1,"dark")
            mesh.box((0,-h*.12,front+.23),(w*.035,w*.22,.03),"white")
        else:
            mesh.cylinder((0,h*.05,front+.15),w*.24,.12,"chrome")
            for i in range(9):
                a=-math.pi*.8+i*math.pi*.2
                mesh.box((math.cos(a)*w*.29,h*.05+math.sin(a)*w*.29,front+.15),(.025,.04,.025),"ink")
            mesh.box((0,h*.12,front+.25),(w*.035,w*.28,.03),"blue")
        labels(mesh,model.upper(),"REAL CONTACT LOGIC",-h*.36,front+.15,w*.78,detail)
    elif model in {"socket","industrialSocket"}:
        mesh.box((0,0,-.04),(w*.9,h*.9,d*.72),"dark" if model=="industrialSocket" else "ivory",.08)
        mesh.cylinder((0,0,d*.38),min(w,h)*.36,.16,"blue" if model=="industrialSocket" else "white")
        count=5 if model=="industrialSocket" else 3
        for i in range(count):
            a=2*math.pi*i/count-math.pi/2
            x=math.cos(a)*min(w,h)*.2; y=math.sin(a)*min(w,h)*.2
            mesh.ring((x,y,d*.49),min(w,h)*.055,min(w,h)*.032,.06,"brass")
        mesh.screw(0,0,d*.5,.06)
        labels(mesh,"3P+N+PE" if model=="industrialSocket" else "L N PE","FEED THROUGH",-h*.39,d*.4,w*.72,detail)
    elif model in {"lamp","bell","buzzer"}:
        mesh.box((0,0,-.12),(w*.78,h*.82,d*.55),"dark",.05)
        if model=="lamp":
            mesh.cylinder((0,0,d*.25),min(w,h)*.34,.22,"chrome")
            mesh.sphere((0,0,d*.43),min(w,h)*.3,"white",scale=(1,1,.55))
            for i in range(8):
                a=2*math.pi*i/8
                mesh.sphere((math.cos(a)*min(w,h)*.18,math.sin(a)*min(w,h)*.18,d*.52),min(w,h)*.035,"yellow")
        elif model=="bell":
            mesh.sphere((0,0,d*.28),min(w,h)*.36,"brass",scale=(1,1,.55))
            mesh.cylinder((0,0,d*.52),min(w,h)*.08,.12,"dark")
            mesh.box((w*.28,-h*.15,d*.32),(w*.12,h*.36,.12),"metal",.02)
        else:
            mesh.cylinder((0,0,d*.3),min(w,h)*.34,.28,"red")
            for r in [.12,.22,.3]: mesh.ring((0,0,d*.46),min(w,h)*r,min(w,h)*(r-.025),.035,"dark")
        labels(mesh,model.upper(),"RATED LOAD",-h*.36,d*.44,w*.62,detail)
    elif model in {"motion","lightSensor","proximity","capacitive","photoelectric","float","pressure","flow"}:
        if model in {"proximity","capacitive"}:
            mesh.cylinder((0,0,0),min(w,h)*.25,d*.9,"metal",axis="x")
            for x in [-w*.2,w*.2]: mesh.ring((x,0,0),min(w,h)*.3,min(w,h)*.24,.12,"brass",axis="x")
            mesh.cylinder((w*.36,0,0),min(w,h)*.24,.12,"dark",axis="x")
        elif model=="photoelectric":
            mesh.box((0,0,0),(w*.62,h*.68,d*.68),"dark",.06)
            mesh.sphere((0,h*.1,d*.4),min(w,h)*.22,"glass",scale=(1,1,.45))
            mesh.sphere((0,-h*.22,d*.38),w*.05,"red")
        elif model=="float":
            mesh.box((0,h*.15,0),(w*.55,h*.45,d*.55),"polymer",.05)
            mesh.cylinder((0,-h*.15,0),w*.08,h*.5,"chrome",axis="y")
            mesh.sphere((0,-h*.38,0),w*.25,"orange",scale=(1,.7,1))
        elif model=="pressure":
            mesh.box((0,-h*.15,0),(w*.58,h*.45,d*.55),"metal",.05)
            mesh.cylinder((0,h*.18,d*.15),w*.28,.18,"chrome")
            mesh.cylinder((0,h*.18,d*.26),w*.22,.04,"white")
            mesh.box((0,h*.25,d*.3),(w*.025,w*.2,.02),"red")
        elif model=="flow":
            mesh.cylinder((0,0,0),w*.18,w*.75,"metal",axis="x")
            for x in [-w*.34,w*.34]: mesh.ring((x,0,0),w*.24,w*.16,.12,"brass",axis="x")
            mesh.box((0,h*.22,0),(w*.36,h*.38,d*.48),"dark",.04)
        else:
            mesh.box((0,0,0),(w*.72,h*.72,d*.62),"ivory",.08)
            mesh.sphere((0,0,d*.4),min(w,h)*.28,"white" if model=="motion" else "glass",scale=(1,1,.55))
            if model=="lightSensor": mesh.ring((0,0,d*.4),min(w,h)*.32,min(w,h)*.28,.08,"dark")
        mesh.sphere((w*.25,-h*.25,d*.35),w*.045,"green")
        labels(mesh,model.upper(),"NO / PNP",-h*.36,d*.4,w*.68,detail)
    elif model in {"ct","vt","bellTransformer"}:
        if model=="ct":
            mesh.box((0,0,0),(w*.84,h*.82,d*.72),"dark",.06)
            mesh.ring((0,0,d*.4),min(w,h)*.3,min(w,h)*.17,d*.28,"black")
            for x in [-w*.3,w*.3]: mesh.screw(x,-h*.32,d*.42,.06,"brass")
        else:
            for i in range(8 if detail=="board" else 14):
                z=(i-(7 if detail=="board" else 13)/2)*d*.045
                mesh.box((0,0,z),(w*.84,h*.76,d*.035),"metal",.02)
            for x in [-w*.22,w*.22]: mesh.cylinder((x,0,d*.25),w*.16,h*.62,"copper",axis="y")
            for y in [-h*.43,h*.43]: mesh.box((0,y,d*.15),(w*.88,h*.12,d*.4),"dark",.02)
        labels(mesh,"CT 100/5" if model=="ct" else "230/100V" if model=="vt" else "230/12V",model.upper(),-h*.35,d*.48,w*.68,detail)
    elif model in {"wattmeter","frequencyMeter"}:
        din_shell(mesh,w,h,d,"dark","polymer")
        mesh.box((0,h*.12,front+.12),(w*.8,h*.4,.12),"black",.03)
        mesh.box((0,h*.12,front+.2),(w*.68,h*.27,.04),"screen",.015)
        mesh.text("50.0 HZ" if model=="frequencyMeter" else "0000 W",h*.12,front+.23,w*.6,h*.15,"screenInk")
        for x in [-w*.22,0,w*.22]: mesh.cylinder((x,-h*.2,front+.15),w*.05,.06,"dark")
        labels(mesh,"FREQ" if model=="frequencyMeter" else "POWER","V I COS PHI",-h*.35,front+.15,w*.72,detail)
    elif model in {"neutralBar","earthBar","distributionBlock"}:
        color="blue" if model=="neutralBar" else "earth" if model=="earthBar" else "orange"
        mesh.box((0,0,-.08),(w*.94,h*.8,d*.5),"dark",.035)
        mesh.box((0,0,d*.28),(w*.88,h*.38,.16),color,.025)
        for i in range(5): mesh.screw((i-2)*w*.18,0,d*.41,.065,"brass")
        labels(mesh,"N" if model=="neutralBar" else "PE" if model=="earthBar" else "DIST",model.upper(),-h*.28,d*.34,w*.7,detail)
    elif model in {"fan","pump","heater","solenoid"}:
        if model=="fan":
            mesh.cylinder((0,0,0),h*.34,w*.3,"polymer",axis="x")
            mesh.cylinder((w*.22,0,0),h*.12,w*.28,"chrome",axis="x")
            for i in range(7):
                a=2*math.pi*i/7
                mesh.box((w*.36,math.cos(a)*h*.16,math.sin(a)*h*.16),(w*.06,h*.28,.07),"blue",.02)
            for r in [.18,.28,.36]: mesh.ring((w*.4,0,0),h*r,h*(r-.015),.025,"metal",axis="x")
        elif model=="pump":
            mesh.cylinder((-w*.15,0,0),h*.3,w*.45,"motorBlue",axis="x")
            mesh.sphere((w*.25,0,0),h*.32,"blue",scale=(.7,1,1))
            mesh.cylinder((w*.42,0,0),h*.15,w*.24,"chrome",axis="x")
            mesh.box((0,-h*.35,0),(w*.7,h*.14,d*.5),"dark",.025)
        elif model=="heater":
            for i in range(3): mesh.cylinder(((i-1)*w*.25,0,0),w*.09,h*.68,"copper",axis="y")
            for y in [-h*.36,h*.36]: mesh.box((0,y,0),(w*.84,h*.12,d*.55),"metal",.025)
            for i in range(8): mesh.box((0,(i-3.5)*h*.08,d*.15),(w*.78,.025,.05),"chrome")
        else:
            mesh.cylinder((0,-h*.15,0),w*.22,w*.55,"brass",axis="x")
            mesh.box((0,h*.18,0),(w*.55,h*.48,d*.62),"dark",.04)
            mesh.cylinder((0,h*.18,d*.36),w*.19,h*.35,"copper",axis="y")
        labels(mesh,model.upper(),"SOLVED LOAD",-h*.36,d*.42,w*.68,detail)
    elif model=="cable":
        for i,color in enumerate(["red","yellow","blue","black","earth"]):
            mesh.cylinder((0,(i-2)*h*.12,0),h*.055,w*.84,color,axis="x")
            for side in [-1,1]: mesh.cylinder((side*w*.46,(i-2)*h*.12,0),h*.035,w*.1,"copper",axis="x")
    terminal_layout(mesh,kind,spec,d,detail)
    return mesh


def build(kind,spec,detail):
    m=Mesh(detail); w,h=[v/48 for v in spec["size"]]; d=depth_for(kind)
    front=d*.56
    if detail!="board" and CURRENT_SOURCE_STEMS:
        append_source_geometry(m,CURRENT_SOURCE_STEMS[0],kind,w,h,d)
        source_refinements(m,kind,spec,w,h,d,detail)
        terminal_layout(m,kind,spec,d,detail)
        return m
    if spec.get("extended"):
        return build_extended(m,kind,spec,detail)
    if kind in {"circuitBreaker","differentialBreaker","motorBreaker"}:
        din_shell(m,w,h,d)
        poles=1 if kind=="circuitBreaker" else 2 if kind=="differentialBreaker" else 3
        if kind=="motorBreaker":
            m.box((0,.05,front+.08),(w*.72,h*.53,.18),"dark",.04)
            m.cylinder((0,.03,front+.22),w*.24,.14,"blue")
            m.cylinder((0,.03,front+.31),w*.1,.035,"chrome")
            m.box((0,.03,front+.34),(w*.035,w*.28,.025),"white")
            labels(m,"MPCB","6-10A",-h*.29,front+.17,w*.78,detail)
        else:
            for p in range(poles):
                x=(p-(poles-1)/2)*w*.34
                m.box((x,h*.04,front+.08),(w*.28,h*.48,.14),"dark",.025)
                m.box((x,h*.04,front+.19),(w*.14,h*.28,.15),"blue",.025)
                m.box((x,h*.11,front+.275),(w*.1,h*.035,.02),"white")
            if kind=="differentialBreaker":
                m.cylinder((w*.31,-h*.24,front+.19),w*.075,.07,"yellow")
                labels(m,"RCD","30MA",-h*.35,front+.14,w*.8,detail)
            else: labels(m,"MCB C10","230V",-h*.29,front+.14,w*.78,detail)
    elif kind=="contactor":
        din_shell(m,w,h,d,"dark","ivory")
        for yy in [-h*.36,h*.36]:
            m.box((0,yy,front+.04),(w*.98,h*.2,.24),"dark",.035)
            for i in range(3): m.screw((i-1)*w*.25,yy,front+.19,.085,"brass")
        m.box((0,h*.02,front+.16),(w*.66,h*.34,.22),"black",.04)
        m.box((0,h*.03,front+.29),(w*.43,h*.13,.05),"glass",.015)
        m.box((0,-h*.12,front+.3),(w*.56,.09,.035),"green")
        for side in [-1,1]:
            m.box((side*w*.4,0,front+.11),(w*.13,h*.43,.16),"polymer",.02)
            for yy in [-h*.12,h*.13]: m.screw(side*w*.39,yy,front+.22,.06)
        labels(m,"K1 3P","A1 A2 24V",-h*.25,front+.23,w*.65,detail)
    elif kind=="thermalRelay":
        din_shell(m,w,h,d,"dark","polymer")
        m.box((0,h*.32,front+.08),(w*.95,h*.22,.22),"black",.025)
        m.cylinder((-w*.18,-h*.02,front+.2),w*.17,.15,"blue")
        m.cylinder((-w*.18,-h*.02,front+.29),w*.06,.035,"chrome")
        for i in range(7):
            a=-math.pi*.8+i*math.pi*.26
            m.box((-w*.18+math.cos(a)*w*.22,-h*.02+math.sin(a)*w*.22,front+.19),(.025,.05,.025),"white")
        m.box((w*.2,h*.02,front+.2),(w*.19,h*.12,.13),"red",.02)
        m.box((w*.2,-h*.16,front+.2),(w*.19,h*.12,.13),"green",.02)
        labels(m,"THERMAL","95 96 97 98",-h*.34,front+.15,w*.75,detail)
    elif kind in {"auxiliaryRelay","timer","timerOffDelay"}:
        din_shell(m,w,h,d)
        if kind=="auxiliaryRelay":
            m.box((0,0,front+.12),(w*.74,h*.64,.2),"glass",.035)
            for x in [-w*.18,w*.18]:
                m.cylinder((x,0,front+.24),w*.12,h*.38,"copper",axis="y")
            m.box((w*.28,0,front+.27),(w*.1,h*.3,.09),"blue",.015)
            labels(m,"RELAY","24V 13 14",-h*.32,front+.18,w*.8,detail)
        else:
            m.box((0,h*.13,front+.12),(w*.75,h*.27,.08),"screen",.02)
            m.text("00.0 S",h*.13,front+.18,w*.62,h*.15,"screenInk")
            for i in range(4): m.cylinder(((i-1.5)*w*.17,-h*.12,front+.16),w*.05,.06,"dark")
            m.cylinder((0,-h*.28,front+.16),w*.12,.1,"blue")
            labels(m,"ON DELAY" if kind=="timer" else "OFF DELAY","A1 A2 15 16 18",-h*.4,front+.14,w*.82,detail)
    elif kind in {"pushButtonNO","pushButtonNC","emergencyStop","selectorSwitch","rotarySwitch","indicator"}:
        m.box((0,0,-.18),(w*.78,h*.92,d*.56),"dark",.05)
        m.cylinder((0,0,d*.16),min(w,h)*.32,d*.36,"chrome")
        m.ring((0,0,d*.38),min(w,h)*.35,min(w,h)*.25,.12,"metal")
        if kind=="emergencyStop" or kind=="rotarySwitch":
            m.box((0,0,d*.36),(w*.88,h*.75,.12),"yellow",.07)
        if kind=="indicator":
            m.sphere((0,0,d*.48),min(w,h)*.28,"statusLens",scale=(1,1,.6))
            m.ring((0,0,d*.42),min(w,h)*.32,min(w,h)*.27,.1,"chrome")
        elif kind=="emergencyStop":
            m.cylinder((0,0,d*.55),min(w,h)*.3,.3,"red",radius_top=min(w,h)*.36)
            m.text("STOP",-h*.27,d*.65,w*.65,h*.12,"ink")
        elif kind in {"selectorSwitch","rotarySwitch"}:
            m.cylinder((0,0,d*.52),min(w,h)*.24,.16,"black")
            m.box((0,min(w,h)*.08,d*.68),(min(w,h)*.12,min(w,h)*.5,.13),"rubber",.025)
            m.box((0,min(w,h)*.25,d*.76),(min(w,h)*.035,min(w,h)*.15,.02),"white")
            if kind=="rotarySwitch" and detail!="board":
                for text,x in [("0",-w*.25),("1",0),("2",w*.25)]: m.text(text,h*.27,d*.52,w*.18,h*.12,"ink",x)
        else:
            color="green" if kind=="pushButtonNO" else "red"
            m.cylinder((0,0,d*.5),min(w,h)*.28,.2,color)
            m.ring((0,0,d*.43),min(w,h)*.32,min(w,h)*.27,.08,"chrome")
            m.text("NO" if kind=="pushButtonNO" else "NC",-h*.28,d*.47,w*.5,h*.12,"white")
        for x in [-w*.24,w*.24]: m.screw(x,-h*.34,d*.25,.06)
    elif kind=="sensor":
        m.cylinder((0,0,0),min(w,h)*.25,d*.9,"metal",axis="x")
        for x in [-w*.2,w*.2]: m.ring((x,0,0),min(w,h)*.3,min(w,h)*.24,.12,"brass",axis="x")
        m.cylinder((w*.36,0,0),min(w,h)*.24,.12,"dark",axis="x")
        m.sphere((-w*.22,h*.18,d*.25),w*.045,"green")
        m.box((0,-h*.28,d*.25),(w*.65,h*.14,.05),"label",.015)
        m.text("PROX NO",-h*.28,d*.29,w*.58,h*.1,"ink")
    elif kind=="limitSwitch":
        m.box((0,-h*.08,0),(w*.65,h*.62,d*.65),"metal",.07)
        m.cylinder((0,h*.25,d*.15),w*.18,.18,"dark")
        m.box((w*.12,h*.36,d*.2),(w*.12,h*.48,.12),"chrome",.02)
        m.cylinder((w*.18,h*.56,d*.2),w*.16,.18,"rubber")
        for x in [-w*.2,w*.2]: m.screw(x,-h*.22,d*.38,.06)
        m.ring((0,-h*.43,0),w*.15,w*.1,.18,"brass")
        labels(m,"LIMIT","NO NC",-h*.05,d*.38,w*.5,detail)
    elif kind in {"motor3Phase","motor1Phase"}:
        body="motorBlue" if kind=="motor3Phase" else "polymer"
        m.cylinder((0,0,0),h*.31,w*.62,body,axis="x")
        for x in [-w*.31,w*.31]: m.cylinder((x,0,0),h*.35,.16,body,axis="x")
        fins=10 if detail=="board" else 18
        for i in range(fins):
            a=2*math.pi*i/fins
            y=math.cos(a)*h*.325; z=math.sin(a)*h*.325
            m.box((0,y,z),(w*.58,.055,.055),body,.012)
        m.cylinder((w*.47,0,0),h*.1,w*.24,"chrome",axis="x")
        m.cylinder((-w*.39,0,0),h*.32,.18,"dark",axis="x")
        if detail!="board":
            for r in [h*.1,h*.18,h*.25]: m.ring((-w*.5,0,0),r,r*.85,.025,"metal",axis="x")
        m.box((0,h*.35,d*.13),(w*.44,h*.3,d*.52),"dark",.04)
        m.box((0,h*.35,d*.43),(w*.38,h*.23,.08),"polymer",.025)
        m.box((w*.54,-h*.24,-d*.08),(w*.78,h*.12,d*.28),body,.02)
        for ix in range(3):
            for iy in [-1,1]: m.screw((ix-1)*w*.12,h*.32+iy*h*.065,d*.5,.065,"brass")
        for x in [-w*.23,w*.23]:
            m.box((x,-h*.36,0),(w*.2,h*.16,d*.5),body,.025)
            m.screw(x,-h*.4,d*.28,.06)
        if kind=="motor1Phase": m.box((-w*.15,h*.13,-d*.35),(w*.34,h*.45,d*.34),"dark",.04)
        m.text("3~" if kind=="motor3Phase" else "1~",h*.32,d*.49,w*.23,h*.13,"ink")
    elif kind=="transformer":
        for i in range(12 if detail!="board" else 6):
            z=(i-5.5)*d*.045
            m.box((0,0,z),(w*.88,h*.8,d*.035),"metal",.025)
        m.box((0,0,d*.22),(w*.25,h*.86,d*.35),"dark")
        for x in [-w*.23,w*.23]:
            m.cylinder((x,0,d*.28),w*.17,h*.66,"copper",axis="y")
            if detail=="detailed":
                for j in range(10): m.ring((x,(j-4.5)*h*.06,d*.28),w*.18,w*.145,.025,"copper",axis="y")
        for x in [-w*.35,w*.35]:
            m.box((x,-h*.45,0),(w*.2,h*.12,d*.65),"dark",.02); m.screw(x,-h*.45,d*.36,.06)
        for y in [-h*.46,h*.46]:
            m.box((0,y,d*.16),(w*.88,h*.12,d*.45),"dark",.025)
        labels(m,"230/24V","50VA",-h*.28,d*.45,w*.52,detail)
    elif kind in {"dcSupply","acSupply","threePhaseSupply"}:
        din_shell(m,w,h,d,"metal","polymer")
        m.box((0,h*.17,front+.09),(w*.78,h*.28,.1),"dark",.025)
        m.text("DC 24V" if kind=="dcSupply" else "1~ 230V" if kind=="acSupply" else "3~ 400V",h*.18,front+.16,w*.68,h*.13,"screenInk")
        for i in range(5 if detail!="board" else 3):
            m.box(((i-2)*w*.13,-h*.08,front+.1),(w*.065,h*.17,.06),"black",.012)
        m.sphere((w*.3,-h*.28,front+.17),w*.04,"green")
        m.cylinder((-w*.28,-h*.28,front+.16),w*.07,.06,"blue")
        labels(m,"POWER","L N PE" if kind!="dcSupply" else "+ 0V",-h*.39,front+.12,w*.8,detail)
    elif kind=="terminalBlock":
        m.box((0,0,0),(w*.9,h*.86,d),"orange",.055)
        for x in [-w*.32,0,w*.32]: m.box((x,0,d*.43),(w*.05,h*.72,.12),"label")
        m.box((0,0,d*.44),(w*.5,h*.18,.12),"metal")
        for y in [-h*.24,h*.24]: m.screw(0,y,d*.55,.09,"brass")
        m.text("PE" if spec["terminals"][0]["kind"]=="earth" else "TB",0,d*.58,w*.45,h*.14,"ink")
    elif kind=="fuse":
        din_shell(m,w,h,d)
        m.box((0,0,front+.1),(w*.78,h*.68,.18),"dark",.035)
        m.cylinder((0,0,front+.22),w*.16,h*.48,"glass",axis="y")
        for y in [-h*.25,h*.25]: m.cylinder((0,y,front+.22),w*.2,h*.08,"chrome",axis="y")
        m.box((w*.3,0,front+.23),(w*.1,h*.43,.12),"polymer",.02)
        m.sphere((-w*.27,-h*.26,front+.24),w*.045,"red")
        labels(m,"FUSE","10A",-h*.38,front+.15,w*.72,detail)
    elif kind in {"voltmeter","ammeter","digitalCounter"}:
        din_shell(m,w,h,d,"dark","polymer")
        m.box((0,h*.12,front+.1),(w*.8,h*.38,.12),"black",.035)
        m.box((0,h*.13,front+.18),(w*.68,h*.25,.04),"screen",.015)
        value="230.0 V" if kind=="voltmeter" else "0.00 A" if kind=="ammeter" else "000.0 KWH"
        m.text(value,h*.13,front+.22,w*.6,h*.15,"screenInk")
        for x in [-w*.22,0,w*.22]: m.cylinder((x,-h*.18,front+.16),w*.055,.07,"dark")
        labels(m,"VOLT" if kind=="voltmeter" else "AMP" if kind=="ammeter" else "ENERGY","V I P",-h*.34,front+.15,w*.74,detail)
    terminal_layout(m,kind,spec,d,detail)
    return m


def parse_catalog():
    text=(ROOT/"lib/src/models/component_catalog.dart").read_text()
    starts=list(re.finditer(r"ComponentKind\.(\w+): (?:ComponentSpec|_buttonSpec)\(",text))
    specs={}
    for i,match in enumerate(starts):
        block=text[match.start():starts[i+1].start() if i+1<len(starts) else len(text)]
        kind=match.group(1)
        size=re.search(r"size: const Size\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\)",block)
        terms=[]
        for t in re.finditer(r"TerminalDefinition\(\s*id: '([^']+)',\s*label: '([^']+)',\s*position: BoardPoint\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\),\s*kind: TerminalKind\.(\w+)",block):
            terms.append({"id":t.group(1),"label":t.group(2),"x":float(t.group(3)),"y":float(t.group(4)),"kind":t.group(5)})
        if kind in {"pushButtonNO","pushButtonNC"}:
            specs[kind]={"size":(82.0,92.0),"terminals":[
                {"id":"input","label":"3","x":41.0,"y":0.0,"kind":"auxiliary"},
                {"id":"output","label":"4","x":41.0,"y":92.0,"kind":"auxiliary"},
            ]}
            continue
        if not size or not terms: raise RuntimeError(f"Cannot parse {kind}: size={size}, terminals={len(terms)}")
        specs[kind]={"size":(float(size.group(1)),float(size.group(2))),"terminals":terms}
    extensions=json.loads((ROOT/"tool/component_catalog_extensions.json").read_text())
    for entry in extensions:
        kind=entry["kind"]
        if kind in specs: raise RuntimeError(f"Duplicate extended spec: {kind}")
        specs[kind]={"size":tuple(entry["size"]),"terminals":entry["terminals"],
                     "model":entry.get("model",kind),"din":entry.get("din",False),
                     "source":entry.get("source"),"extended":True}
    enum=(ROOT/"lib/src/models/terminal.dart").read_text()
    body=re.search(r"enum ComponentKind\s*\{([^}]+)\}",enum,re.S).group(1)
    order=re.findall(r"\b(\w+)\s*(?:,|$)",body)
    missing=set(order)-set(specs)
    extra=set(specs)-set(order)
    if missing or extra: raise RuntimeError(f"Catalog mismatch: missing={missing}, extra={extra}")
    return [(kind,specs[kind]) for kind in order]


def refine_large_triangles(mesh):
    """Reduce painter-sort artifacts on broad enclosure panels.

    Small hardware is left untouched. Only broad triangles are subdivided, which
    keeps GLB size and software-rendering cost bounded while preventing a large
    back-panel triangle from cutting through a screen or technical label.
    """
    refined=[]
    def area(a,b,c):
        u=[mesh.vertices[b][i]-mesh.vertices[a][i] for i in range(3)]
        v=[mesh.vertices[c][i]-mesh.vertices[a][i] for i in range(3)]
        cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        return math.sqrt(sum(q*q for q in cross))*.5
    def midpoint(a,b):
        index=len(mesh.vertices)
        mesh.vertices.append(tuple((mesh.vertices[a][i]+mesh.vertices[b][i])*.5 for i in range(3)))
        return index
    def emit(a,b,c,material,level=0):
        if level<3 and area(a,b,c)>.12:
            ab=midpoint(a,b);bc=midpoint(b,c);ca=midpoint(c,a)
            emit(a,ab,ca,material,level+1);emit(ab,b,bc,material,level+1)
            emit(ca,bc,c,material,level+1);emit(ab,bc,ca,material,level+1)
        else: refined.append(([a,b,c],material))
    for indices,material in mesh.faces:
        for i in range(1,len(indices)-1): emit(indices[0],indices[i],indices[i+1],material)
    mesh.faces=refined


def export_glb(mesh,path,kind,detail):
    refine_large_triangles(mesh)
    material_names=sorted({mat for _,mat in mesh.faces})
    material_index={name:i for i,name in enumerate(material_names)}
    grouped=defaultdict(list)
    for indices,mat in mesh.faces:
        for i in range(1,len(indices)-1): grouped[mat].extend((indices[0],indices[i],indices[i+1]))
    binary=bytearray(); views=[]; accessors=[]
    def view(data,target):
        while len(binary)%4: binary.append(0)
        offset=len(binary); binary.extend(data)
        views.append({"buffer":0,"byteOffset":offset,"byteLength":len(data),"target":target})
        return len(views)-1
    pos=b"".join(struct.pack("<fff",*v) for v in mesh.vertices)
    pos_view=view(pos,34962)
    mins=[min(v[i] for v in mesh.vertices) for i in range(3)]
    maxs=[max(v[i] for v in mesh.vertices) for i in range(3)]
    accessors.append({"bufferView":pos_view,"componentType":5126,"count":len(mesh.vertices),"type":"VEC3","min":mins,"max":maxs})
    primitives=[]
    for mat in material_names:
        indices=grouped[mat]
        idx_view=view(b"".join(struct.pack("<I",i) for i in indices),34963)
        accessors.append({"bufferView":idx_view,"componentType":5125,"count":len(indices),"type":"SCALAR"})
        primitives.append({"attributes":{"POSITION":0},"indices":len(accessors)-1,"material":material_index[mat],"mode":4})
    materials=[]
    for name in material_names:
        value=C[name]
        materials.append({"name":name,"pbrMetallicRoughness":{
            "baseColorFactor":[((value>>16)&255)/255,((value>>8)&255)/255,(value&255)/255,1],
            "metallicFactor":.75 if name in {"metal","chrome","brass","copper"} else .05,
            "roughnessFactor":.28 if name in {"metal","chrome","brass","copper"} else .62}})
    document={"asset":{"version":"2.0","generator":"ELEC LAB calibrated GLB generator","copyright":"ELEC LAB project; original geometry and user-supplied starter pack"},
              "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":f"{kind}-{detail}","mesh":0,"extras":{"componentKind":kind,"lod":detail,"terminalIds":[t["id"] for t in CURRENT_SPEC["terminals"]],"terminalsCalibrated":True,"sourceAssets":[f"models/{stem}.glb" for stem in CURRENT_SOURCE_STEMS]}}],
              "meshes":[{"name":kind,"primitives":primitives}],"materials":materials,
              "bufferViews":views,"accessors":accessors,"buffers":[{"byteLength":len(binary)}]}
    raw_json=json.dumps(document,separators=(",",":"),ensure_ascii=False).encode()
    while len(raw_json)%4: raw_json+=b" "
    while len(binary)%4: binary.append(0)
    total=12+8+len(raw_json)+8+len(binary)
    data=struct.pack("<III",0x46546C67,2,total)+struct.pack("<II",len(raw_json),0x4E4F534A)+raw_json+struct.pack("<II",len(binary),0x004E4942)+binary
    path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
    return {"path":str(path.relative_to(ROOT)).replace("\\","/"),"bytes":len(data),"vertices":len(mesh.vertices),
            "triangles":sum(len(v)//3 for v in grouped.values()),"materials":len(material_names),
            "sha256":hashlib.sha256(data).hexdigest(),"bounds":{"min":mins,"max":maxs}}


def main():
    global CURRENT_SPEC,CURRENT_SOURCE_INFO,CURRENT_SOURCE_STEMS
    parser=argparse.ArgumentParser(); parser.parse_args()
    manifest={"format":"elec-lab-glb-manifest","version":2,"license":"ELEC LAB original assets and user-supplied starter pack; see docs/ASSETS_3D.md","models":[]}
    used_sources=set()
    for kind,spec in parse_catalog():
        CURRENT_SPEC=spec
        CURRENT_SOURCE_STEMS=list(SOURCE_MAP.get(kind,[]))
        if spec.get("source"): CURRENT_SOURCE_STEMS=[spec["source"]]
        CURRENT_SOURCE_INFO=[read_source_glb(stem)[2] for stem in CURRENT_SOURCE_STEMS]
        used_sources.update(CURRENT_SOURCE_STEMS)
        entry={"kind":kind,"terminalIds":[t["id"] for t in spec["terminals"]],
               "sourceAssets":CURRENT_SOURCE_INFO,"lods":{}}
        for detail in ["board","preview","detailed"]:
            mesh=build(kind,spec,detail)
            entry["lods"][detail]=export_glb(mesh,OUT/detail/f"{kind}.glb",kind,detail)
        manifest["models"].append(entry)
        print(f"{kind:24} " + " ".join(f"{d}:{entry['lods'][d]['triangles']}tri" for d in entry["lods"]))
    available={path.stem for path in SOURCE_ROOT.glob("*.glb")}
    if used_sources!=available:
        raise RuntimeError(f"Source pack usage mismatch: unused={available-used_sources}, missing={used_sources-available}")
    manifest["sourcePack"]={"files":len(available),"allUsed":True}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n")
    print(f"Generated {len(manifest['models'])*3} GLB files in {OUT}; all {len(available)} source GLBs used")

if __name__=="__main__": main()
