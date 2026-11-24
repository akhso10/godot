"""Author the atmospheric masks for Sekolah Setelah Tengah Malam with NumPy and Pillow."""
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]/"assets/vfx"
N=256
y,x=np.mgrid[-1:1:complex(N),-1:1:complex(N)]
rng=np.random.default_rng(2347)

def mask(name,a,color):
    rgb=Image.new("RGBA",(N,N),color)
    rgb.putalpha(Image.fromarray((np.clip(a,0,1)*255).astype("uint8")))
    rgb.save(ROOT/(name+".png"), optimize=True)

def field(blur):
    values=gaussian_filter(rng.normal(size=(N,N)),blur,mode="wrap")
    return (values-values.min())/np.ptp(values)

def smooth(s):
    return np.clip(s,0,1)**2*(3-2*np.clip(s,0,1))

def pencil(name, line_sets):
    canvas=Image.new("RGBA",(N*4,N*4),(255,255,255,0))
    draw=ImageDraw.Draw(canvas)
    for vertices,width,alpha in line_sets:
        draw.line([(int(a*4),int(b*4)) for a,b in vertices], fill=(203,225,224,alpha), width=int(width*4))
    canvas.resize((N,N),Image.Resampling.LANCZOS).save(ROOT/(name+".png"))

ROOT.mkdir(exist_ok=True,parents=True)
radius=np.hypot(x,y)
noise=field(11)*.5+field(4)*.3+field(1.3)*.2
mask("dust_particle",np.exp(-radius**2*7)*smooth((1-radius)*3),"#ddd4a8")
mask("mist_particle",np.sin(np.pi*np.clip(1-radius,0,1)/2)**2*noise*.82,"#a5b6b0")
mask("flashlight_cookie",np.exp(-radius**2*3.2)*(1+.08*np.cos(radius*28)) *smooth((1-radius)*7),"#fff8ce")
mask("light_halo",np.exp(-radius*6)*smooth((1-radius)*2),"#ffdf9c")
mask("shadow_smoke",smooth((1-radius)*3)*smooth((noise-.21)*2),"#171e24")
mask("vignette",smooth((radius-.38)*.94),"#0b1414")
mask("flicker_mask",smooth(.35+.25*np.cos(y*3.3)+.28*noise),"#142a2c")
mask("paranormal_distortion",np.sin(11*y+2*x+noise*14)**24*noise*smooth((1-radius)*4),"#517870")
for name,sigma,tone in [("camera_noise",.8,"#afc5c2"),("static_noise",.18,"#d3e7db"),("subtle_film_grain",.35,"#101e20")]:
    mask(name,field(sigma),tone)
# A raindrop streak with an asymmetric, tapered bright head.
mask("rain_particle",np.exp(-((x-.065*y)/(.025+.028*(y+1)))**2)*smooth((1-abs(y))*4)*(.29+.39*(y+1)),"#accbd3")
droplets=np.zeros((N,N))
for _ in range(140):
    cx,cy=rng.uniform(-1,1,2)
    rx=rng.uniform(.006,.032)
    ry=rx*rng.uniform(1.3,3.9)
    rxv=(x-cx)/rx
    ryv=(y-cy)/ry
    drop=np.exp(-((rxv+.25)**2+(ryv+.41)**2)*9)+.25*np.exp(-((rxv**2+ryv**2-.85)**2)*19)
    droplets=np.maximum(droplets,drop)
mask("window_droplets",droplets,"#c3d9d5")
crack=[]
for i in range(8):
    angle=i*np.pi/4+rng.uniform(-.21,.21)
    head=np.array([114.,141.]); path=[head.copy()]
    for j in range(rng.integers(4,8)):
        bend=angle+rng.uniform(-.42,.42)
        head=head+np.array([np.cos(bend),np.sin(bend)])*rng.uniform(10,26)
        path.append(head.copy())
        if j in (1,3):
            direction=bend+rng.choice([-1,1])*.71
            crack.append(([head.copy(),head+np.array([np.cos(direction),np.sin(direction)])*22],.65,110))
    crack.append((path,1.1,164))
pencil("glass_crack",crack)
foot=np.maximum(smooth((1-((x/0.38)**2+((y+.31)/.51)**2))*7),smooth((1-(((x+.04)/.31)**2+((y-.54)/.29)**2))*7))
tread=(.56+.44*smooth((np.sin((y+.25*abs(x))*61)-.29)*3))*(.67+.33*field(.5))
mask("wet_footprint",foot*tread,"#273a38")
