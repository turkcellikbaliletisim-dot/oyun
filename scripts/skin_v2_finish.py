#!/usr/bin/env python3
"""Finish skin v2: original geometry + generated materials, and synthesized audio.

No font binaries are distributed. The generated art and deterministic composites
are separately identified in manifest_v2.json. Audio is explicitly provisional
procedural sound design, not an ElevenLabs/Suno/Udio recording.
"""
from __future__ import annotations
from pathlib import Path
from functools import lru_cache
import hashlib, io, json, math, tempfile, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import cairosvg
import soundfile as sf
from scipy import signal
import skin_v2_build as b
import skin_v2_fonts

ROOT=b.ROOT; SKIN=b.SKIN; DOC=b.DOC; L=Image.Resampling.LANCZOS
DEFS='''<defs>
<linearGradient id="gold" x2="0.3" y2="1"><stop stop-color="#fff1b0"/><stop offset=".27" stop-color="#e7bc52"/><stop offset=".49" stop-color="#895418"/><stop offset=".68" stop-color="#f9d983"/><stop offset="1" stop-color="#916021"/></linearGradient>
<linearGradient id="steel" x2="1" y2="1"><stop stop-color="#ffffff"/><stop offset=".36" stop-color="#bad7dc"/><stop offset=".5" stop-color="#66808a"/><stop offset=".72" stop-color="#e8f3ed"/><stop offset="1" stop-color="#466674"/></linearGradient>
<linearGradient id="leather" x2="0" y2="1"><stop stop-color="#614330"/><stop offset=".4" stop-color="#291c21"/><stop offset="1" stop-color="#16181e"/></linearGradient>
<radialGradient id="teal" cx=".3" cy=".2" r=".9"><stop stop-color="#43b4b6"/><stop offset=".4" stop-color="#125b6d"/><stop offset="1" stop-color="#10242f"/></radialGradient>
<radialGradient id="blue" cx=".3" cy=".2" r=".9"><stop stop-color="#b8faff"/><stop offset=".38" stop-color="#158afa"/><stop offset="1" stop-color="#10247a"/></radialGradient>
<radialGradient id="ruby" cx=".3" cy=".2" r=".9"><stop stop-color="#ffad76"/><stop offset=".33" stop-color="#d72a25"/><stop offset="1" stop-color="#601024"/></radialGradient>
<radialGradient id="green" cx=".3" cy=".2" r=".9"><stop stop-color="#bfec86"/><stop offset=".34" stop-color="#27946b"/><stop offset="1" stop-color="#123c36"/></radialGradient>
<linearGradient id="paper" x2="1" y2="1"><stop stop-color="#fff8d5"/><stop offset=".5" stop-color="#ecd293"/><stop offset="1" stop-color="#95662f"/></linearGradient>
</defs>'''

def svg(body,w,h,vw=None,vh=None):
    data=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {vw or w} {vh or h}">{DEFS}{body}</svg>'
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=data.encode()))).convert('RGBA')

def star(cx,cy,r,inner,points=8):
    return ' '.join(f'{cx+math.cos(-math.pi/2+i*math.pi/points)*(r if i%2==0 else inner):.2f},{cy+math.sin(-math.pi/2+i*math.pi/points)*(r if i%2==0 else inner):.2f}' for i in range(points*2))

def resize(im,size):return im.convert('RGBa').resize(size,L).convert('RGBA')

def patch_to(patch,size):
    w,h=size;pw,ph=patch.size
    if w<=pw and h<=ph:return resize(patch,(w,h))
    tw,th=min(w,pw),min(h,ph);tile=resize(patch,(tw,th));out=Image.new('RGBA',(w,h))
    for y in range(0,h,th):
        for x in range(0,w,tw):out.alpha_composite(tile,(x,y))
    return out

def nine_slice(im,size,edge=72):
    w,h=size;sw,sh=im.size;bb=max(4,min(sw,sh)//5);dx=min(edge,w//3);dy=min(edge,h//3)
    sx=[0,bb,sw-bb,sw];sy=[0,bb,sh-bb,sh];xx=[0,dx,w-dx,w];yy=[0,dy,h-dy,h];out=Image.new('RGBA',size)
    for j in range(3):
        for i in range(3):
            p=im.crop((sx[i],sy[j],sx[i+1],sy[j+1]))
            out.alpha_composite(patch_to(p,(xx[i+1]-xx[i],yy[j+1]-yy[j])),(xx[i],yy[j]))
    return out

def main():
    SKIN.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((SKIN/'manifest_v2.json').read_text());records=manifest['assets']
    specs=json.loads(b.SOURCE_LIST.read_text());expected=json.loads(b.EXPECTED_LIST.read_text());sources={}
    with tempfile.TemporaryDirectory(prefix='skin-v2-finish-') as td:
        cache=Path(td)
        def raw(name):
            if name not in sources:
                _,im,meta=b.download((name,specs[name]),cache);sources[name]=(im,meta)
            return sources[name][0].copy()
        @lru_cache(None)
        def cut(name):
            im=raw(name);kind=specs[name]['kind'];im=b.matte(im,kind) if kind in b.TRANSPARENT_KINDS else im.convert('RGBA')
            if kind!='black':im=b.clean_matte_debris(im)
            return im.crop(b.bounds(im))
        def finish(name,art,source_names=(),**details):
            target=tuple(expected[name+'.png'])
            if art.width<target[0]*2 or art.height<target[1]*2:raise ValueError('Below 2x composite canvas: '+name)
            info={'method':'original geometry and generated-material composite','generated_independently':False,'source_asset_names':list(source_names),'source_size':list(art.size),'source_at_least_2x_each_dimension':True,'resample_scale':target[0]/art.width}
            info.update(details);out=resize(art,target)
            aa=out.getchannel('A');dd=ImageDraw.Draw(aa);dd.rectangle((0,0,out.width-1,out.height-1),outline=0,width=2);out.putalpha(aa)
            if name=='app_icon_foreground':
                aa=out.getchannel('A');dd=ImageDraw.Draw(aa);m=math.ceil(target[0]*.17)
                dd.rectangle((0,0,target[0],m-1),fill=0);dd.rectangle((0,target[1]-m,target[0],target[1]),fill=0);dd.rectangle((0,0,m-1,target[1]),fill=0);dd.rectangle((target[0]-m,0,target[0],target[1]),fill=0);out.putalpha(aa)
            records[name+'.png']=b.save_asset(name,out,info)
            print('COMPOSITE',name,flush=True)
        def detail(art):
            src=cut('tooltip_panel');src=src.crop((src.width//3,src.height//3,src.width*2//3,src.height*2//3))
            tex=np.asarray(patch_to(src,art.size).convert('RGB'),dtype=np.float32);lum=tex.mean(2);grain=np.clip((lum-lum.mean())/max(float(lum.std()),8),-2,2)
            a=np.asarray(art,dtype=np.float32).copy();a[:,:,:3]*=1+grain[:,:,None]*.055;a[:,:,:3]=np.clip(a[:,:,:3],0,255);a[a[:,:,3]==0,:3]=0
            return Image.fromarray(a.astype('uint8'),'RGBA')
        # Shared app emblem: original crescent, sword and quill over painted inlay.
        emblem=Image.new('RGBA',(2048,2048));plate=cut('table_center');plate.thumbnail((1470,1470),L);emblem.alpha_composite(plate,((2048-plate.width)//2,(2048-plate.height)//2))
        body=f'''<polygon points="{star(500,500,354,247)}" fill="url(#teal)" stroke="url(#gold)" stroke-width="14"/>
<g transform="rotate(-43 500 500)"><path d="M479 252L500 136L521 252V671H479Z" fill="url(#steel)" stroke="#34505b" stroke-width="5"/><path d="M500 155V666" stroke="#efffff" stroke-width="5"/><path d="M397 654Q500 629 603 654L590 684Q500 665 410 684Z" fill="url(#gold)" stroke="#573716" stroke-width="7"/><rect x="479" y="679" width="42" height="132" rx="11" fill="#492a24" stroke="url(#gold)" stroke-width="9"/><path d="M484 700L516 713M484 727L516 740M484 754L516 767" stroke="#d4a94f" stroke-width="6"/><circle cx="500" cy="825" r="28" fill="url(#gold)"/></g>
<g transform="rotate(41 500 500)"><path d="M490 743C352 573 438 226 596 145C613 357 549 536 490 743Z" fill="url(#paper)" stroke="#815a22" stroke-width="6"/><path d="M481 813Q498 433 592 163" fill="none" stroke="url(#gold)" stroke-width="12"/><path d="M494 678L438 590M501 627L430 515M514 572L441 445M527 518L458 381M543 458L483 317M561 389L514 258M495 682L539 635M504 623L561 560M519 558L580 487M535 493L593 411M552 424L601 341" stroke="#b98d40" stroke-width="5"/></g>
<path d="M674 297A258 258 0 1 0 674 703A218 218 0 1 1 674 297Z" fill="url(#gold)" stroke="#704917" stroke-width="8"/><polygon points="{star(650,465,55,25,5)}" fill="url(#gold)" stroke="#946729" stroke-width="5"/>'''
        emblem.alpha_composite(svg(body,2048,2048,1000,1000));used=emblem.crop(b.bounds(emblem));used.thumbnail((1344,1344),L);fg=Image.new('RGBA',(2048,2048));fg.alpha_composite(used,((2048-used.width)//2,(2048-used.height)//2))
        finish('app_icon_foreground',fg,('table_center',),adaptive_safe_fraction=.66)
        bg=ImageOps.fit(raw('backdrop').convert('RGB'),(2048,2048),L).convert('RGBA')
        bg.alpha_composite(svg('<path d="M0 1000L1000 0V1000Z" fill="#63152d" opacity=".65"/><rect x="24" y="24" width="952" height="952" fill="none" stroke="url(#gold)" stroke-width="16"/><rect x="49" y="49" width="902" height="902" fill="none" stroke="#177582" stroke-width="7"/>',2048,2048,1000,1000));bg.alpha_composite(fg)
        records['app_icon.png']=b.save_asset('app_icon',bg.convert('RGB').resize((1024,1024),L),{'method':'original emblem over generated stone background','generated_independently':False,'source_size':[2048,2048],'source_at_least_2x_each_dimension':True,'corner_rounding':False})
        # Typeset exact dotted-I wordmark; retain no font binaries.
        fonts=cache/'fonts';font_report=skin_v2_fonts.install(fonts,True)
        (DOC/'font-validation.json').write_text(json.dumps(font_report,ensure_ascii=False,indent=2)+'\n')
        b.create_brand(fonts,records,{'app_icon_background':bg})
        # create_brand uses a 1K foreground internally: replace app_icon with the verified 2K composition.
        records['app_icon.png']=b.save_asset('app_icon',bg.convert('RGB').resize((1024,1024),L),{'method':'original emblem over generated stone background','generated_independently':False,'source_size':[2048,2048],'source_at_least_2x_each_dimension':True,'corner_rounding':False})
        records['logo_wordmark.png'].update(generated_independently=False,source_at_least_2x_each_dimension=True)
        # Progress rail with transparent, measured fill area.
        loading=svg('''<path d="M88 10H1512L1544 80L1512 150H88L56 80Z" fill="url(#gold)" stroke="#5c3913" stroke-width="8"/><path d="M89 80L122 35L155 80L122 125Z M1445 80L1478 35L1511 80L1478 125Z" fill="url(#blue)" stroke="#ffe5a0" stroke-width="6"/>''',1600,160)
        aa=loading.getchannel('A');ImageDraw.Draw(aa).rectangle((158,27,1442,133),fill=0);loading.putalpha(aa)
        finish('loading_bar_frame',loading,(),fill_rect_px=[79,14,721,66],nine_slice_margins_px=[80,13,80,13])
        # Radial burst and complete hollow rounded-rectangle glows.
        sz=2048;yy,xx=np.mgrid[0:sz,0:sz].astype(np.float32);xx=(xx-sz/2)/sz;yy=(yy-sz/2)/sz;r=np.hypot(xx,yy);ang=np.arctan2(yy,xx)
        rays=np.clip(np.cos(23*ang+.5*np.sin(5*ang)),0,1)**30;ray2=np.clip(np.cos(37*ang-1.2),0,1)**60
        alpha=np.clip(np.exp(-(r/.085)**2)*.98+rays*np.exp(-r/.20)*1.35+ray2*np.exp(-r/.29)*.72,0,1)*np.clip((.46-r)/.07,0,1)
        core=np.exp(-(r/.12)**2);rgb=np.stack((np.ones_like(r),.61+.36*core,.12+.70*core),axis=2);arr=np.uint8(np.dstack((rgb,alpha))*255);arr[arr[:,:,3]==0,:3]=0
        finish('pack_reveal_burst',Image.fromarray(arr,'RGBA'),(),method='original 2048px procedural radial gold burst')
        for name,col in [('fx_glow_ready',(133,255,113)),('fx_glow_legend',(255,219,117))]:
            art=Image.new('RGBA',(512,512));mask=Image.new('L',(512,512));d=ImageDraw.Draw(mask);d.rounded_rectangle((58,46,454,466),radius=46,outline=255,width=8)
            soft=mask.filter(ImageFilter.GaussianBlur(14));layer=Image.new('RGBA',art.size,(*col,0));layer.putalpha(soft);art.alpha_composite(layer)
            core=Image.new('RGBA',art.size,(255,249,210,0));core.putalpha(mask.filter(ImageFilter.GaussianBlur(2)));art.alpha_composite(core)
            a=art.getchannel('A');ad=ImageDraw.Draw(a);ad.rounded_rectangle((95,83,417,429),radius=16,fill=0);ad.rectangle((0,0,511,9),fill=0);ad.rectangle((0,502,511,511),fill=0);ad.rectangle((0,0,9,511),fill=0);ad.rectangle((502,0,511,511),fill=0);art.putalpha(a)
            finish(name,art,(),method='original complete rounded rectangle glow; true alpha and hollow center')
        # Blank book, with dimensional geometry and high-resolution painted material grain.
        book=svg('''<ellipse cx="604" cy="665" rx="427" ry="57" fill="#0f1720" opacity=".28"/><path d="M136 275Q367 187 600 302Q831 187 1064 275L1078 600Q829 564 600 673Q371 564 122 600Z" fill="url(#leather)" stroke="#462821" stroke-width="20"/><path d="M160 285Q380 220 600 325L600 637Q374 554 146 570Z M600 325Q820 220 1040 285L1054 570Q826 554 600 637Z" fill="url(#paper)" stroke="#8a612d" stroke-width="9"/><path d="M160 532Q367 518 585 597M157 549Q367 535 585 614M1041 532Q830 518 615 597M1044 549Q830 535 615 614" fill="none" stroke="#a5773c" stroke-width="5"/><path d="M181 259Q394 213 599 325L599 608Q369 518 168 533Z M601 325Q805 213 1019 259L1032 533Q831 518 601 608Z" fill="url(#paper)" stroke="#fff3bb" stroke-width="6"/><path d="M599 326V607" stroke="#855824" stroke-width="13"/><path d="M577 602V718L605 696L633 720V602" fill="#176b72" stroke="url(#gold)" stroke-width="7"/><path d="M155 286L186 275L180 314M1034 286L1003 275L1010 314M141 573L174 571L171 548M1059 573L1026 571L1029 548" fill="none" stroke="url(#gold)" stroke-width="18" stroke-linecap="round"/><circle cx="755" cy="175" r="7" fill="#ffe39c"/><circle cx="894" cy="187" r="5" fill="#ffeab8"/><circle cx="843" cy="126" r="8" fill="#eab855"/><path d="M823 207V229M812 218H834" stroke="#fff5bd" stroke-width="5"/><ellipse cx="988" cy="627" rx="78" ry="32" fill="#8f826e" opacity=".16"/>''',1200,800)
        finish('empty_collection',detail(book),('tooltip_panel',),method='original blank illuminated book geometry with generated material texture')
        off=svg('''<path d="M100 911L164 419L405 166L892 112L1374 423L1512 955Q825 1117 100 911Z" fill="#233f49" opacity=".18"/><ellipse cx="783" cy="1004" rx="439" ry="70" fill="#101c25" opacity=".32"/><path d="M557 411V262Q557 155 674 155Q791 155 791 262V411" fill="none" stroke="url(#gold)" stroke-width="26"/><path d="M453 416L510 302H838L895 416Z" fill="url(#gold)" stroke="#49371d" stroke-width="17"/><path d="M477 433H872L830 931H516Z" fill="url(#teal)" stroke="#6e501f" stroke-width="22"/><path d="M493 442L534 915M856 442L814 915M674 443V916" fill="none" stroke="url(#gold)" stroke-width="24"/><path d="M493 443H855M518 917H832" stroke="#eed78b" stroke-width="13"/><path d="M494 919H854L895 972H455Z" fill="url(#gold)" stroke="#49351b" stroke-width="18"/><path d="M551 642Q589 674 626 642M722 642Q761 674 797 642" fill="none" stroke="#102b36" stroke-width="16" stroke-linecap="round"/><path d="M560 477L579 578" stroke="#bdd3c8" stroke-width="13" opacity=".46"/><g fill="none" stroke="url(#gold)" stroke-width="23"><ellipse cx="980" cy="869" rx="75" ry="42" transform="rotate(-35 980 869)"/><ellipse cx="1070" cy="817" rx="67" ry="40" transform="rotate(-32 1070 817)"/><path d="M1109 749Q1129 698 1172 711Q1213 730 1187 772M1256 809Q1284 783 1317 809Q1344 839 1311 873"/><ellipse cx="1350" cy="903" rx="67" ry="40" transform="rotate(42 1350 903)"/></g>''',1600,1200)
        finish('offline',detail(off),('tooltip_panel',),method='original unlit sleeping lantern and broken-chain illustration with painted material grain')
        # Renew previous low-resolution atlas assets without enlarging those crops.
        button=nine_slice(cut('end_turn_ready'),(1104,328),72)
        for name,color in [('button_gold',None),('button_dark',(41,31,34)),('button_red',(128,14,30))]:
            art=Image.new('RGBA',(1200,360));plate=button.copy()
            if color:
                layer=Image.new('RGBA',plate.size,(*color,0));mask=Image.new('L',plate.size);ImageDraw.Draw(mask).rounded_rectangle((198,61,906,266),radius=34,fill=245);layer.putalpha(mask.filter(ImageFilter.GaussianBlur(9)));plate.alpha_composite(layer)
            art.alpha_composite(plate,(48,16));finish(name,art,('end_turn_ready',),nine_slice_margins_px=[100,32,100,32])
        base=nine_slice(cut('tooltip_panel'),(942,1252),86)
        for name,tone in [('frame_unit',None),('frame_spell',(25,138,210)),('frame_trap',(79,48,108)),('frame_legend',(241,183,58))]:
            rim=base.copy()
            if tone:
                a=np.asarray(rim,dtype=np.float32).copy();lum=a[:,:,:3].mean(2)/255;target=np.clip(lum[:,:,None]*np.array(tone)*1.4,0,255);a[:,:,:3]=a[:,:,:3]*.36+target*.64;rim=Image.fromarray(a.astype('uint8'),'RGBA')
            art=Image.new('RGBA',(1024,1360));art.alpha_composite(rim,(41,54))
            art.alpha_composite(svg('<path d="M109 950H915V1225L866 1281H158L109 1225Z" fill="url(#leather)" stroke="url(#gold)" stroke-width="12"/><path d="M173 1226H851" stroke="#bd9140" stroke-width="4"/><path d="M93 121H931V922H93Z" fill="none" stroke="url(#gold)" stroke-width="14"/>',1024,1360))
            aa=art.getchannel('A');ImageDraw.Draw(aa).rounded_rectangle((106,135,918,909),radius=22,fill=0);art.putalpha(aa)
            if name=='frame_spell':art.alpha_composite(svg(''.join(f'<circle cx="{x}" cy="{y}" r="32" fill="url(#blue)" stroke="#bdefff" stroke-width="7"/>' for x,y in [(90,112),(934,112),(90,1254),(934,1254)]),1024,1360))
            if name=='frame_trap':art.alpha_composite(svg('''<ellipse cx="512" cy="104" rx="101" ry="44" fill="#211d2c" stroke="url(#gold)" stroke-width="8"/><path d="M448 95Q512 142 576 95M469 112L457 129M491 121L485 142M514 126V148M538 120L545 141M558 110L571 127" fill="none" stroke="#d7b365" stroke-width="9" stroke-linecap="round"/><g fill="none" stroke="#a6a1b2" stroke-width="10"><ellipse cx="91" cy="990" rx="23" ry="38"/><ellipse cx="94" cy="1040" rx="20" ry="36"/><ellipse cx="933" cy="990" rx="23" ry="38"/><ellipse cx="930" cy="1040" rx="20" ry="36"/></g>''',1024,1360))
            if name=='frame_legend':art.alpha_composite(svg('''<path d="M414 142L386 75L461 105L512 55L563 105L638 75L610 142Z" fill="url(#gold)" stroke="#8b591b" stroke-width="8"/><path d="M61 319L43 214L81 267L43 145L93 209L45 91L134 190L92 320Z M963 319L981 214L943 267L981 145L931 209L979 91L890 190L932 320Z" fill="url(#gold)" stroke="#8b591b" stroke-width="5"/><path d="M490 115L512 81L534 115L512 140Z" fill="url(#blue)" stroke="#fff0b0" stroke-width="4"/>''',1024,1360))
            finish(name,art,('tooltip_panel',),art_window_px=[53,68,459,455],text_plate_px=[62,482,450,621],closed_eye=name=='frame_trap')
        mana=svg('''<polygon points="256,25 411,117 429,349 256,487 83,349 101,117" fill="url(#gold)" stroke="#765019" stroke-width="14"/><polygon points="256,68 373,139 388,330 256,443 124,330 139,139" fill="url(#blue)" stroke="#94eaff" stroke-width="9"/><path d="M256 69L209 218L140 139M209 218L124 330L256 355L388 330L301 218L374 139M256 69L301 218L256 355L256 443M209 218H301" fill="none" stroke="#8fd8fa" stroke-width="6" opacity=".7"/><path d="M147 145L215 104" stroke="#edffff" stroke-width="13" stroke-linecap="round"/>''',512,512)
        attack=svg('''<circle cx="256" cy="256" r="226" fill="url(#gold)" stroke="#754519" stroke-width="15"/><circle cx="256" cy="256" r="187" fill="url(#ruby)" stroke="#ffc57c" stroke-width="8"/><path d="M155 105L231 206L350 117M231 206L148 324L283 394L381 279L350 117M231 206L381 279M148 324L93 233" fill="none" stroke="#ffca87" stroke-width="6" opacity=".28"/><path d="M104 203Q127 133 182 108" fill="none" stroke="#fff0b0" stroke-width="12" stroke-linecap="round"/>''',512,512)
        health=svg('''<circle cx="256" cy="256" r="226" fill="url(#gold)" stroke="#735020" stroke-width="15"/><circle cx="256" cy="256" r="192" fill="url(#green)" stroke="#bceca8" stroke-width="7"/><path d="M256 405C203 359 99 276 113 187C124 113 213 110 256 169C299 110 388 113 399 187C413 276 309 359 256 405Z" fill="url(#ruby)" stroke="url(#gold)" stroke-width="13"/><path d="M145 193Q155 151 205 162" fill="none" stroke="#ffe8ad" stroke-width="13" stroke-linecap="round"/>''',512,512)
        for name,art in [('gem_mana',mana),('gem_attack',attack),('gem_health',health)]:finish(name,detail(art),('tooltip_panel',),method='original bold badge geometry with generated material grain')
        # Reconstruct wide rails instead of squeezing them into tiny center areas.
        for name,edge in [('header_bar',110),('input_field',66),('toast_banner',130),('progress_frame',36)]:
            w,h=expected[name+'.png'];art=Image.new('RGBA',(w*2,h*2));marginx=math.ceil(w*.08);marginy=max(6,math.ceil(h*.08));rail=nine_slice(cut(name),(w*2-marginx*2,h*2-marginy*2),edge);art.alpha_composite(rail,(marginx,marginy))
            if name=='progress_frame':
                aa=art.getchannel('A');ImageDraw.Draw(aa).rectangle((marginx+80,marginy+16,w*2-marginx-80,h*2-marginy-16),fill=0);art.putalpha(aa)
            finish(name,art,(name,),nine_slice_margins_px=[edge//2,max(4,edge//3),edge//2,max(4,edge//3)])
        nav=Image.new('RGBA',(2340,400));nav.alpha_composite(nine_slice(cut('header_bar'),(2152,352),78),(94,24));socket=cut('badge_count');socket.thumbnail((246,246),L);centers=[]
        for f in [.125,.375,.625,.875]:
            x=round(2340*f);nav.alpha_composite(socket,(x-socket.width//2,215-socket.height//2));centers.append([x//2,107])
        finish('nav_bar',nav,('header_bar','badge_count'),socket_centers_px=centers,socket_count=4)
        eye=Image.new('RGBA',(512,512));p=cut('icon_type_trap');p.thumbnail((464,464),L);eye.alpha_composite(p,((512-p.width)//2,(512-p.height)//2));eye.alpha_composite(svg('<circle cx="256" cy="256" r="144" fill="#292236"/><path d="M142 211Q256 326 370 211M174 249L157 279M214 272L203 308M256 283V322M298 272L309 308M338 249L355 279" fill="none" stroke="url(#gold)" stroke-width="17" stroke-linecap="round"/>',512,512));finish('icon_type_trap',eye,('icon_type_trap',),closed_eye=True)
        b.typography_preview(fonts,records)
    # Technical verification reopens every PNG and checks hashes and alpha.
    missing=sorted(set(expected)-set(records));assert not missing,missing
    for name,size in expected.items():
        p=SKIN/name;im=Image.open(p);im.load();assert list(im.size)==size,(name,im.size)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==records[name]['sha256'],name
        if im.mode=='RGBA':
            aa=np.asarray(im.getchannel('A'));assert aa.min()==0 and aa.max()>0,name
            assert max(aa[0].max(),aa[-1].max(),aa[:,0].max(),aa[:,-1].max())==0,name
    audio=make_audio()
    report={k:v for k,v in manifest.items() if k!='assets'}
    report.update(package='Yeni gorsel 2 - completed file set',png_count=len(records),expected_png_count=len(expected),missing_png=[],errors=[],fonts_validated=True,font_binaries_in_package=False,audio_files_generated=len(audio),audio_status='14 provisional procedural sound-design files; NOT generated by ElevenLabs/Suno/Udio; acoustic instrument authenticity not claimed',device_or_gameplay_tested=False,independent_ai_png_count=sum(v.get('generated_independently') is True for v in records.values()),composite_png_count=sum(v.get('generated_independently') is False for v in records.values()))
    report['font_install_command']='bash scripts/skin_v2_fonts.command';report['audio']=audio
    (SKIN/'manifest_v2.json').write_text(json.dumps(dict(report,assets=records),ensure_ascii=False,indent=2)+'\n');(DOC/'build-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    b.preview_grid([n for n in records if n.startswith('icon_')],'icons.jpg',records,7,(220,190))
    b.preview_grid([n for n in records if n.startswith('fx_') or n=='pack_reveal_burst.png'],'effects.jpg',records,5,(240,210))
    other=[n for n in records if not n.startswith(('icon_','fx_','chapter_','enemy_','hero_player_alt','scene_','chest_')) and n not in {'backdrop.png','splash.png'}]
    b.preview_grid(other,'interface.jpg',records,4,(420,250))
    write_docs(report)
    print(json.dumps({k:v for k,v in report.items() if k!='audio'},indent=2),flush=True)

# Layered deterministic sound design. No third-party samples or neural music.
SR=44100;RNG=np.random.default_rng(20261012)
def timeline(seconds):return np.arange(round(seconds*SR),dtype=np.float64)/SR

def fade(x,attack=.004,release=.05):
    x=np.asarray(x,dtype=np.float64).copy();a=min(round(attack*SR),len(x)//2);z=min(round(release*SR),len(x)//2)
    if a:x[:a]*=np.sin(np.linspace(0,math.pi/2,a))**2
    if z:x[-z:]*=np.cos(np.linspace(0,math.pi/2,z))**2
    return x

def noise(seconds,low=200,high=8000):
    x=RNG.normal(0,.4,round(seconds*SR));sos=signal.butter(2,[low,high],btype='band',fs=SR,output='sos');return signal.sosfilt(sos,x)

def bell(f,d):
    t=timeline(d);x=sum(np.sin(2*np.pi*f*k*t)*np.exp(-t*(2+k*.6)/d)/k**1.4 for k in [1,2.01,2.73,4.08]);return fade(x,.004,.07)

def drum(d=.65,f=67):
    t=timeline(d);phase=2*np.pi*(f*t+65*.018*(1-np.exp(-t/.018)));x=np.sin(phase)*np.exp(-t*8)+.24*noise(d,100,4200)*np.exp(-t*32);return fade(x,.001,.06)

def reed(f,d,bright=False):
    t=timeline(d);vib=.003*np.sin(2*np.pi*5.1*t)*np.clip(t/.22,0,1);phase=2*np.pi*np.cumsum(f*(1+vib))/SR
    x=sum(np.sin(k*phase)/k**(1.35 if bright else 2.2) for k in range(1,9));x+=noise(d,800,6000)*(.12 if bright else .19)
    return fade(x,.055 if not bright else .025,.13)

def pluck(f,d=2):
    t=timeline(d);x=sum(np.sin(2*np.pi*f*k*t+.015*k)*np.exp(-t*(1.5+.36*k))/k**1.25 for k in range(1,10));x+=noise(d,800,6500)*np.exp(-t*70)*.12;return fade(x,.002,.08)

def mix(d,events):
    x=np.zeros(round(SR*d),dtype=np.float64)
    for start,snd,gain in events:
        i=round(start*SR);n=min(len(snd),len(x)-i)
        if n>0:x[i:i+n]+=snd[:n]*gain
    return fade(x,.001,min(.13,d*.22))

def make_audio():
    folder=SKIN/'audio';folder.mkdir(exist_ok=True);rows={}
    def save(name,x,loop=False):
        x=np.asarray(x,dtype=np.float64);x-=x.mean(axis=0);peak=np.max(np.abs(x));x=x*(.72/max(float(peak),.001));path=folder/(name+'.ogg')
        channels=1 if x.ndim==1 else x.shape[1]
        print('ENCODE',name,flush=True)
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac',str(channels),'-i','pipe:0','-c:a','libvorbis','-q:a','5',str(path)],input=np.asarray(x,dtype='<f4').tobytes(),check=True,timeout=120)
        decoded=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-ar',str(SR),'-ac',str(channels),'pipe:1'],capture_output=True,check=True,timeout=120)
        data=np.frombuffer(decoded.stdout,dtype='<f4').reshape(-1,channels);sr=SR
        assert sr==SR and abs(len(data)-len(x))<=round(SR*.02) and np.isfinite(data).all();assert np.max(np.abs(data))<1
        rows[path.name]={'file':'native/skin/audio/'+path.name,'sample_rate':sr,'channels':data.shape[1],'duration_seconds':len(data)/sr,'loop':loop,'method':'original procedural multi-layer synthesis; provisional','peak_after_decode':float(np.max(np.abs(data))),'seam_jump':float(np.max(np.abs(data[0]-data[-1]))) if loop else None,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        print('AUDIO',name,len(data)/sr,flush=True)
    t=timeline(.1);save('click',fade((.6*np.sin(2*np.pi*790*t)+.22*np.sin(2*np.pi*1920*t))*np.exp(-t*64)+noise(.1,800,7000)*np.exp(-t*85),.001,.035))
    t=timeline(.5);save('play_card',mix(.5,[(0,noise(.5,300,4500)*np.sin(np.pi*np.minimum(t/.22,1))**2,.45),(.14,drum(.35,117),.75),(.15,noise(.3,900,5500)*np.exp(-timeline(.3)*35),.55)]))
    t=timeline(.6);save('attack',mix(.6,[(0,noise(.6,500,9500)*np.exp(-((t-.17)/.10)**2),.75),(.22,bell(1370,.38),.28),(.22,drum(.38,100),.55)]))
    save('hit',mix(.4,[(0,drum(.4,83),1),(.006,bell(391,.39),.13)]))
    save('heal',mix(.8,[(0,bell(523,.8),.38),(.12,bell(659,.68),.34),(.25,bell(784,.55),.30),(.4,bell(1047,.4),.16)]))
    t=timeline(.9);save('spell',mix(.9,[(0,noise(.9,300,8000)*np.sin(np.pi*t/.9)**2,.4),(.13,reed(659,.7),.2),(.34,bell(1318,.56),.23)]))
    save('turn_start',mix(1.2,[(0,drum(.8,65),.7),(.12,reed(440,.40,True),.23),(.45,reed(659,.65,True),.3),(.45,drum(.7,76),.25)]))
    t=timeline(.4);save('end_turn',fade((np.sin(2*np.pi*119*t)+.4*np.sin(2*np.pi*173.7*t)+.25*np.sin(2*np.pi*337*t))*np.exp(-t*9),.008,.1))
    events=[]
    for st,f,d in [(0,440,.45),(.42,554,.4),(.81,659,.5),(1.28,880,1.65)]:events.append((st,reed(f,d,True),.35))
    for st in [0,.4,.8,1.28]:events.append((st,drum(.7,65),.5))
    for f in [220,277.18,329.63]:events.append((1.28,reed(f,1.7),.15))
    save('victory',mix(3,events));save('defeat',mix(3,[(0,reed(220,2.9),.4),(.42,reed(207.65,2.5),.2),(0,bell(110,3),.3),(1.3,reed(164.81,1.7),.25)]))
    t=timeline(2.5);creak=noise(2.5,180,1600)*np.exp(-((t-.45)/.25)**2)*(.6+.4*np.sin(2*np.pi*13*t))
    save('pack_open',mix(2.5,[(0,creak,.7),(.67,drum(.5,95),.35)]+[(.8+i*.13,bell(f,2.5-.8-i*.13),.16) for i,f in enumerate([523,659,784,1047,1318,1568])]))
    t=timeline(.3);save('card_flip',fade(noise(.3,1300,8500)*(np.exp(-((t-.07)/.025)**2)+.8*np.exp(-((t-.16)/.035)**2)),.002,.04))
    # Both loops are 96 seconds. All event tails wrap; delays are circular.
    for name,beat,bars in [('music_menu',.75,32),('music_battle',.5,48)]:
        duration=96;n=round(duration*SR);x=np.zeros(n,dtype=np.float64);t=np.arange(n)/SR;battle=name=='music_battle'
        for f,g in [(110,.06),(165,.025),(220,.018)]:
            freq=round(f*duration)/duration;x+=np.sin(2*np.pi*freq*t)*g*(1+.09*np.sin(2*np.pi*4*t/duration))
        def add(st,snd,g):
            i=round(st*SR)%n;end=min(n,i+len(snd));x[i:end]+=snd[:end-i]*g
            if end-i<len(snd):x[:len(snd)-(end-i)]+=snd[end-i:]*g
        motif=[57,64,62,61,58,61,62,64,65,64,62,58,57,61,58,57]
        hz=lambda m:440*2**((m-69)/12)
        for bar in range(bars):
            st=bar*4*beat;root=[45,45,46,43][(bar//4)%4]
            for k in range(4):add(st+k*beat,pluck(hz(root+12+(7 if k%2 else 0)),2.5),.10 if not battle else .065)
            if bar%4 in [0,1,2]:
                for k in [0,2]:add(st+k*beat,reed(hz(motif[(bar*2+k//2)%len(motif)]),beat*1.8,battle),.065 if not battle else .07)
            if battle:
                for k in [0,1.5,2,3.5]:add(st+k*beat,drum(.55,64 if k in [0,2] else 90),.25 if k in [0,2] else .13)
                for k in [.5,1,2.5,3]:add(st+k*beat,fade(noise(.17,1000,7000)*np.exp(-timeline(.17)*22),.001,.045),.13)
            elif bar%2==0:add(st,drum(.75,58),.055)
        x=np.tanh(x*1.1);left=x+.17*np.roll(x,round(.19*SR))+.08*np.roll(x,round(.37*SR));right=x+.17*np.roll(x,round(.23*SR))+.08*np.roll(x,round(.43*SR))
        save(name,np.column_stack((left,right)),True)
    (folder/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
    (folder/'README.md').write_text('# Provisional procedural audio\n\n14 original synthesized OGG/Vorbis files, 44.1 kHz. These are layered procedural sound-design assets, not outputs of ElevenLabs, Suno or Udio and not recordings of authentic acoustic instruments. Both 96-second music files wrap event tails and reverb for looping. Technical decode/peak checks passed; listening and in-game mix approval remain pending. No third-party audio samples are used.\n')
    return rows

def write_docs(report):
    text='''# Yeni g\u00f6rsel 2 - teslim durumu

## Dosyalar
114 PNG: ikinci listedeki 104 yeni g\u00f6rsel ve ilk paketten yenilenen 4 kart \u00e7er\u00e7evesi, 3 buton, 3 rozet. Adlar ve boyutlar `skin_v2_expected.json` ile do\u011frulan\u0131r. Yeni g\u00f6rseller `native/skin/` i\u00e7indedir. 40 kart sahnesi ve oyun kodu de\u011fi\u015ftirilmedi.

## \u00dcretim y\u00f6ntemi
\u00c7o\u011fu kaynak tek tek yapay zek\u00e2yla \u00fcretildi. Son eksikler ve geometrisi d\u00fczeltilen aray\u00fczler, \u00fcretilmi\u015f malzemelerle \u00f6zg\u00fcn vekt\u00f6r/kompozit olarak tamamland\u0131; bunlar ba\u011f\u0131ms\u0131z yapay zek\u00e2 \u00e7izimi de\u011fildir. Eski atlas k\u0131rp\u0131mlar\u0131 b\u00fcy\u00fct\u00fclmedi. Kompozit tuvalleri hedefin 2 kat\u0131nda i\u015flendi; kaynak detaylar\u0131 b\u00fcy\u00fct\u00fclmeden d\u00f6\u015fendi/k\u00fc\u00e7\u00fclt\u00fcld\u00fc. Bu, b\u00fct\u00fcn par\u00e7alar\u0131n ba\u011f\u0131ms\u0131z 2x AI \u00fcretim oldu\u011fu anlam\u0131na gelmez. Dosya baz\u0131nda y\u00f6ntem `manifest_v2.json` i\u00e7indedir.

## D\u00fczeltmeler
- Tuzak ikonunda ve \u00e7er\u00e7evesinde kapal\u0131 g\u00f6z.
- Alt men\u00fcde tam d\u00f6rt yuva; kart parlamalar\u0131nda tam kapal\u0131 dikd\u00f6rtgen ve \u015feffaf orta.
- Geni\u015f ba\u015fl\u0131k/giri\u015f/bildirim \u015feritleri; \u00e7er\u00e7eve resim pencereleri ve dolum alan\u0131 koordinatlar\u0131 manifestte.
- Uygulama ikonu opak ve k\u00f6\u015feleri yuvarlat\u0131lmam\u0131\u015f; adaptif \u00f6n plan orta %66 i\u00e7indedir.
- Logo yaz\u0131s\u0131 ger\u00e7ek fontla `DESTAN D\u0130YARLARI` olarak dizildi.

## Fontlar
Font dosyalar\u0131 depoya/pakete dahil de\u011fildir. Proje k\u00f6k\u00fcnde `bash scripts/skin_v2_fonts.command` \u00e7al\u0131\u015ft\u0131r\u0131l\u0131nca resmi kaynaklardan kurulur. Font kurulumu ve T\u00fcrk\u00e7e/rakam glyph test raporu `yeni-gorsel-2/font-validation.json` i\u00e7indedir. Kurulum yap\u0131lmadan oyunun fontu de\u011fi\u015fmez; rol ba\u011flant\u0131lar\u0131 uygulama kodunda ayr\u0131ca yap\u0131lmal\u0131d\u0131r.

## Ses
`native/skin/audio/` i\u00e7inde 14 OGG/Vorbis dosyas\u0131, 44.1 kHz bulunur. Bunlar \u00f6zg\u00fcn, katmanl\u0131 **ge\u00e7ici prosed\u00fcrel ses tasar\u0131m\u0131d\u0131r**. ElevenLabs/Suno/Udio \u00fcretimi veya ger\u00e7ek saz/ney/zurna kayd\u0131 olarak sunulmaz. M\u00fczikler 96 saniye ve d\u00f6ng\u00fcye uygun kuyruklarla haz\u0131rland\u0131. Kulakla dinleme, oyun i\u00e7i miks ve nihai m\u00fczik onay\u0131 yap\u0131lmad\u0131.

## Test kapsam\u0131
PNG a\u00e7\u0131labilirli\u011fi, boyut, hash, alfa ve kenar kontrol\u00fc; ses format\u0131/s\u00fcresi/\u00f6rnekleme oran\u0131/ta\u015fma kontrol\u00fc yap\u0131l\u0131r. `actual-size.png` font ve 32px ikon \u00f6nizlemesidir; ger\u00e7ek cihaz/oynan\u0131\u015f testi de\u011fildir. G\u00f6rseller kod taraf\u0131na hen\u00fcz ba\u011flanmad\u0131.
'''
    (ROOT/'dokumanlar'/'YENI-GORSEL-2.md').write_text(text,encoding='utf-8')
    (SKIN/'README.md').write_text('# Destan Diyarlar\u0131 - skin\n\n\u0130kinci paket: `manifest_v2.json` ve `../../dokumanlar/YENI-GORSEL-2.md`. \u0130lk paketin `manifest.json` dosyas\u0131 tarihsel kay\u0131tt\u0131r; yenilenen frame/button/gem dosyalar\u0131 i\u00e7in v2 manifest kullan\u0131n. Fontlar i\u00e7in proje k\u00f6k\u00fcnde `bash scripts/skin_v2_fonts.command`.\n',encoding='utf-8')

if __name__=='__main__':main()
