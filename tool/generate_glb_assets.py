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


def depth_for(kind):
    if kind=="motor3Phase": return 1.65
    if kind=="motor1Phase": return 1.45
    if kind in {"indicator","pushButtonNO","pushButtonNC","emergencyStop","selectorSwitch","rotarySwitch"}: return 1.05
    if kind in {"sensor","limitSwitch"}: return .9
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


def build(kind,spec,detail):
    m=Mesh(detail); w,h=[v/48 for v in spec["size"]]; d=depth_for(kind)
    front=d*.56
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
    enum=(ROOT/"lib/src/models/terminal.dart").read_text()
    body=re.search(r"enum ComponentKind\s*\{([^}]+)\}",enum,re.S).group(1)
    order=re.findall(r"\b(\w+)\s*(?:,|$)",body)
    missing=set(order)-set(specs)
    if missing: raise RuntimeError(f"Missing specs: {missing}")
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
    document={"asset":{"version":"2.0","generator":"ELEC LAB original industrial mesh generator","copyright":"ELEC LAB project; original geometry"},
              "scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":f"{kind}-{detail}","mesh":0,"extras":{"componentKind":kind,"lod":detail,"terminalIds":[t["id"] for t in CURRENT_SPEC["terminals"]]}}],
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
    global CURRENT_SPEC
    parser=argparse.ArgumentParser(); parser.parse_args()
    manifest={"format":"elec-lab-glb-manifest","version":1,"license":"ELEC LAB original assets; see docs/ASSETS_3D.md","models":[]}
    for kind,spec in parse_catalog():
        CURRENT_SPEC=spec
        entry={"kind":kind,"terminalIds":[t["id"] for t in spec["terminals"]],"lods":{}}
        for detail in ["board","preview","detailed"]:
            mesh=build(kind,spec,detail)
            entry["lods"][detail]=export_glb(mesh,OUT/detail/f"{kind}.glb",kind,detail)
        manifest["models"].append(entry)
        print(f"{kind:24} " + " ".join(f"{d}:{entry['lods'][d]['triangles']}tri" for d in entry["lods"]))
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Generated {len(manifest['models'])*3} GLB files in {OUT}")

if __name__=="__main__": main()
