"""Render SMA Nusa Bangsa's original Foley, weather beds and score as Vorbis.
Requires Python 3, NumPy, SciPy and ffmpeg. Run from any directory.
"""
import hashlib
from pathlib import Path
import subprocess
import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000
TAU = 2 * np.pi


def clock(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def rng(name):
    return np.random.default_rng(int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "little"))


def noise(t, rand, low, high):
    sos = signal.butter(2, [low, high], btype="bandpass", fs=RATE, output="sos")
    out = signal.sosfilt(sos, rand.standard_normal(len(t)))
    return out / max(.001, out.std())


def sine(t, hz):
    return np.sin(TAU * hz * t)


def envelope(t, release, attack=.002):
    return -np.expm1(-t / attack) * np.exp(-t / release)


def ring(t, hz, release, partials=(1., 2.71, 4.09, 6.25)):
    return sum(sine(t, hz * r) * envelope(t, release / (1 + i * .6)) / (1 + i) ** 1.65
               for i, r in enumerate(partials) if hz * r < RATE / 2)


def add(track, when, sample, gain=1.):
    begin = int(when * RATE)
    count = min(len(sample), len(track) - begin)
    if count > 0:
        track[begin:begin + count] += sample[:count] * gain


def echo(x, taps):
    y = x.copy()
    for when, gain in taps:
        add(y, when, x, gain)
    return y


def record(folder, name, mono, peak=.65, loop=False):
    # Asymmetric early reflections avoid a hard centre without masking transients.
    stereo = np.stack([echo(mono, [(.031, .11), (.131, .06)]),
                       echo(mono, [(.045, .13), (.193, .05)])], axis=1)
    if loop:
        # Overlap the tail onto the head. The remaining seam is sample-contiguous.
        overlap = int(.4 * RATE)
        weight = np.linspace(0, 1, overlap)[:, None]
        stereo[:overlap] = stereo[-overlap:] * (1-weight) + stereo[:overlap] * weight
        stereo = stereo[:-overlap]
    else:
        end = min(len(stereo) // 3, int(.08 * RATE))
        stereo[-end:] *= np.linspace(1, 0, end)[:, None]
    stereo *= peak / max(.001, np.abs(stereo).max())
    dest = ROOT / folder / (name + ".ogg")
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "s16le",
                    "-ar", str(RATE), "-ac", "2", "-i", "pipe:0", "-c:a", "libvorbis",
                    "-q:a", "2", str(dest)], input=np.rint(stereo*32767).astype("<i2").tobytes(), check=True)


def weather():
    for name in ["rain_heavy_loop","rain_light_loop","distant_thunder","night_wind","school_room_tone",
                 "fluorescent_hum","distant_whispers","library_ambience","archive_ambience",
                 "generator_loop","outdoor_night"]:
        r = rng(name)
        t = clock(11.4)
        air = noise(t,r,35,570)
        if name.startswith("rain_"):
            density = 600 if "heavy" in name else 180
            x = .15 * air + .32 * noise(t,r,550,7900)
            p = clock(.075)
            for when in r.uniform(0,t[-1],density):
                frequency = r.uniform(550,3300)
                drop = sine(p,frequency*(1+.01*p)) * envelope(p,.012)
                add(x,when,drop,r.uniform(.04,.52))
        elif name == "distant_thunder":
            x = noise(t,r,28,116) * (envelope(t,2,.14) + .85 * np.exp(-((t-2.1)/.31)**2))
            x += .3 * noise(t,r,115,660) * envelope(t,.3,.02)
        elif name == "generator_loop":
            phase = TAU*29*t + .18*sine(t,1.1)
            x = (.6*np.sin(phase) + .25*np.sin(phase*3) + .14*np.sin(phase*6)) * (1+.12*sine(t,6)) + air*.13
        elif name == "fluorescent_hum":
            x = (.55*sine(t,100)+.19*sine(t,200)+.09*sine(t,450)) * (.8+.14*sine(t,2.3)) + .09*air
        elif name == "outdoor_night":
            x = air*.14 + .05*noise(t,r,2100,4700)
            for start in np.arange(.6,11,1.74):
                p = clock(.45)
                chirp = sine(p,3180) * np.maximum(0,sine(p,24))**2 * np.sin(np.pi*p/.45)**2
                add(x,start,chirp,.35)
        elif name == "distant_whispers":
            x = .04*air
            for start in (1.1,3.6,4.05,8.2):
                p = clock(.75)
                breath = noise(p,r,650,2800)*np.sin(np.pi*p/.75)**2
                add(x,start,breath,.55)
        elif name in ("archive_ambience","library_ambience"):
            x = air*.19 + sine(t,49.9)*.13
            for when in r.uniform(0,10,13):
                p = clock(.26)
                add(x,when,noise(p,r,900,3300)*envelope(p,.042,.014),.2)
        elif name == "night_wind":
            x = (.26 + .12*np.sin(.9*t) + .12*np.cos(1.7*t))*air + .07*sine(t,180+ .23*sine(t,.24))
        else:
            x = .15*air + .2*sine(t,50) + .02*noise(t,r,1700,4000)
        record("ambience",name,x,.52,loop=name!="distant_thunder")


def foley():
    names = ["door_open","door_close","door_locked","door_creak","key_pickup","item_pickup","paper_turn",
             "radio_static","flashlight_click","battery_change","switch_toggle","fuse_insert","generator_start",
             "locker_open","locker_close","puzzle_success","puzzle_failure","school_bell","distant_knock",
             "metal_drag","glass_creak","guardian_breath","guardian_footstep","guardian_detect","guardian_chase",
             "jumpscare_01","jumpscare_02","jumpscare_03","heartbeat_slow","heartbeat_fast"]
    names += [f"footstep_{surface}_{i:02d}" for surface in ("ceramic","concrete","wood","water") for i in [1,2]]
    for name in names:
        r = rng(name)
        t = clock(4.4 if name in ("school_bell","generator_start","guardian_chase") else 2.0)
        x = np.zeros(len(t))
        p = clock(.48)
        hit = ring(p,82,.064,(1,1.59,2.22)) + .35*noise(p,r,160,1400)*envelope(p,.032)
        click = noise(p,r,850,7500)*envelope(p,.008,.0005)
        if name in ("school_bell","key_pickup","puzzle_success","puzzle_failure","guardian_detect"):
            notes = {"school_bell": [(0,709),(1.12,709)], "key_pickup":[(0,1460),(.08,1790),(.135,1185)],
                     "puzzle_success":[(0,330),(.16,495),(.36,660)],"puzzle_failure":[(0,169),(.18,157)],
                     "guardian_detect":[(0,87),(.28,164),(.48,179)]}[name]
            duration = 1.55 if name=="school_bell" else .37
            for when,hz in notes:
                add(x,when,ring(t,hz,duration))
            x=echo(x,[(.13,.27),(.29,.19),(.43,.11)])
        elif name.startswith("footstep_") or name == "guardian_footstep":
            material = name.split("_")[1]
            d = r.uniform(.065,.096)
            sole = noise(p,r,430,3400)*envelope(p,d,.024)
            if material == "wood":
                sole += ring(p,r.uniform(190,238),.08)
            elif material == "water":
                sole = noise(p,r,700,5600)*envelope(p,.08,.018)
                for when in r.uniform(.03,.19,8):
                    add(sole,when,ring(p,r.uniform(500,2150),.011),.68)
            elif material == "concrete":
                sole += .6*noise(p,r,1700,5500)*envelope(p,.025)
            add(x,.003,hit,1.45)
            add(x,r.uniform(.060,.102),sole,.45)
            if name == "guardian_footstep":
                add(x,.22,ring(t,54,.39),1.)
        elif name.startswith("heartbeat_"):
            interval = .46 if name.endswith("fast") else .9
            for when in np.arange(0,t[-1]-.1,interval):
                add(x,when,ring(p,59,.058,(1,1.7)))
                add(x,when+.115,ring(p,74,.042,(1,1.62)),.62)
        elif name in ("radio_static","paper_turn","item_pickup","guardian_breath","metal_drag","glass_creak"):
            low,high,decay = {"radio_static":(630,3700,.53),"paper_turn":(900,6700,.17),
                              "item_pickup":(380,3200,.12),"guardian_breath":(270,1900,.61),
                              "metal_drag":(400,4200,.66),"glass_creak":(1900,6800,.41)}[name]
            x=noise(t,r,low,high)*envelope(t,decay,.045) * (.52+.48*np.sin(t*(10+r.uniform(2,9)))**2)
            if name in ("metal_drag","glass_creak"):
                x+=sine(t,low+21*sine(t,4))*.48*envelope(t,decay,.12)
            if name=="radio_static":
                x+=.35*sine(t,1300)*envelope(t,.06)
        elif name=="distant_knock":
            for when,amount in [(0,.87),(.26,.7),(.65,1)]:
                add(x,when,hit,amount)
            x=echo(x,[(.1,.32),(.22,.18)])
        elif name.startswith("jumpscare") or name=="guardian_chase":
            pitch = r.uniform(59,99)
            x=ring(t,pitch,.49,(1,1.08,2.19,3.38)) + .55*noise(t,r,100,2340)*envelope(t,.27,.019)
            x+=.27*sine(t,180+8*t)*envelope(t,.6,.05)
        elif name=="generator_start":
            rev=32*t+5*np.exp(-t/.9)
            x=(np.sin(TAU*rev)+.4*np.sin(TAU*rev*3))*(1-np.exp(-t))*np.minimum(1,4.4-t)
            for when in [0,.22,.53]:
                add(x,when,hit,.8)
        elif name in ("door_open","door_close","locker_open","locker_close","door_creak","door_locked"):
            metal=name.startswith("locker")
            if "open" in name or name == "door_creak":
                x+=sine(t,(264 if metal else 124)+6*sine(t,3)) * envelope(t,.29,.07)
                x+=.35*noise(t,r,300,1890)*envelope(t,.31,.06)
                add(x,.49,click,.77)
            else:
                add(x,.01,hit,1.45)
                add(x,.074,ring(p,331 if metal else 136,.091),.63)
                add(x,.16,click,.37)
        else:
            add(x,0,click)
            hz = {"flashlight_click":640,"switch_toggle":448,"battery_change":284,"fuse_insert":570}[name]
            add(x,.018,ring(p,hz,.021),.47)
            if name in ("battery_change","fuse_insert"):
                add(x,.29,click,.67)
                add(x,.33,ring(p,751,.045),.3)
        last=np.where(np.abs(x)>.001)[0]
        if len(last):
            x=x[:last[-1]+int(.10*RATE)]
        folder = "footsteps" if name.startswith("footstep_") else "effects"
        record(folder,name,x)


def score():
    # Each scene has its own scale, register, rhythm and density. Endings share the
    # descending school-call motif; only the dawn arrangement resolves to the tonic.
    arrangements = {
        "main_menu_theme":(49,[0,7,13,12,7,3], [0,2.3,5.6,8,12.5,15.4],.15),
        "prologue_theme":(55,[7,12,15,10,7], [1,4,6.2,12,15.6],.11),
        "exploration_ambient":(44,[12,19,13,7], [2,5.5,11.9,17],.07),
        "mystery_theme":(51,[0,3,10,15,13,7], [0,2.9,4.4,9.3,13.1,16],.16),
        "tension_theme":(46,[0,1,7,1,8,7,1], [0,1.5,4.5,7,9.7,12.7,16.2],.38),
        "chase_theme":(48,[0,0,7,1,0,7,1,13], list(np.arange(8)*2.15),.81),
        "final_escape_theme":(52,[0,7,13,12,1,8,7,0], list(np.arange(8)*2.0),.89),
        "good_ending_theme":(55,[12,7,14,16,19,12,7,0], [0,2.2,4.5,7.2,10,12.8,14.9,17.1],.09),
        "neutral_ending_theme":(53,[12,7,10,3,7,13], [0,3.1,5.4,8.9,12.3,16.5],.14),
        "bad_ending_theme":(46,[12,7,1,0,1], [0,3.6,7.4,11.3,16.1],.27),
    }
    for name,(root,notes,onsets,pulse) in arrangements.items():
        r=rng(name)
        t=clock(20.4)
        x=(sine(t,root)+.36*sine(t,root*1.498)+.22*sine(t,root*2.005))*(.15+.045*sine(t,.10))
        x+=.028*noise(t,r,93,580)*(.55+.3*sine(t,.17))
        for i,(when,note) in enumerate(zip(onsets,notes)):
            pitch=root*4*2**(note/12)
            sample=ring(t,pitch,.9 if pulse>.5 else 1.52,(1,2.007,3.009,5.32,7.18))
            add(x,when+.08,sample,.63 if i%3==0 else .40)
            add(x,when+.37,sample,.13)
        beat= .495 if pulse>.55 else 1.85
        for i,when in enumerate(np.arange(.34,t[-1],beat)):
            add(x,when,ring(clock(.75),root*(1.5 if i%4==3 else 1),.146,(1,2,3.11)),pulse*(.8 if i%2 else 1))
        record("music",name,x,.68,loop=True)


if __name__=="__main__":
    weather()
    foley()
    score()
