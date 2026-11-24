"""Generate original periodic surface maps. --size 1024 regenerates at master resolution."""
import argparse
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates, gaussian_filter
from PIL import Image

SURFACES = {
 'plaster_ivory': ('wall','c6c2ae'), 'school_green':('wall','678d78'),
 'cracked_plaster':('crack','acae9b'), 'damp_plaster':('damp','889782'),
 'burned_plaster':('burn','514c42'), 'floor_grey':('tile','9ba29b'),
 'toilet_white':('tile','e2e2d5'),'toilet_green':('tile','70a48d'),
 'rough_concrete':('stone','91918a'),'wet_asphalt':('asphalt','484e4b'),
 'paving':('paver','929086'),'desk_wood':('wood','9d7655'),
 'door_wood':('wood','93704d'),'shelf_wood':('wood','7b644b'),
 'rusty_iron':('rust','947b64'),'painted_iron':('iron','537c64'),
 'cabinet_metal':('iron','8c9793'),'window_glass':('glass','91aeae'),
 'dirty_glass':('glass','8d9b91'),'uniform_white':('weave','dfdcd3'),
 'uniform_grey':('weave','717579'),'hoodie_navy':('weave','3e5262'),
 'jacket_maroon':('weave','784955'),'pack_olive':('weave','747956'),
 'aged_paper':('paper','cbb891'),'scuffed_plastic':('plastic','686b63'),
 'roof_tiles':('roof','a4654c'),'damp_soil':('soil','645d47'),
 'tropical_leaf':('leaf','547455')
}
DEFAULT=Path(__file__).resolve().parents[1]/'assets'/'materials'
def make(name,kind,color,root,n,seed):
 y,x=np.mgrid[:n,:n]/n
 rand=np.random.default_rng(seed)
 def noise(freq):
  a=rand.normal(size=(freq,freq))
  return map_coordinates(a,[y*freq,x*freq],order=3,mode='grid-wrap')
 cloud=noise(5)*.54+noise(18)*.26+noise(48)*.13
 grain=noise(110)*.16+rand.normal(0,.12,(n,n))
 h=.28*cloud+.1*grain
 tint=.06*cloud+.033*grain
 rough=np.full((n,n),.85)
 metal=None
 def groove(axis,reps,width):
  d=np.abs((axis*reps+.5)%1-.5)
  return np.clip(1-d/width,0,1)
 if kind in ('crack','damp','burn','rust'):
  t=np.clip((cloud+.17)*1.45,0,1)
  if kind=='crack': t=groove(x+.037*noise(5)+.011*noise(20),2,.015)
  tint-=t*(.35 if kind=='burn' else .23)
  h-=t*.65
  rough-=t*.19
 if kind in ('tile','paver'):
  rx=3 if kind=='tile' else 4; ry=3 if kind=='tile' else 8
  stagger=(np.floor(y*ry)%2)*.5/rx if kind=='paver' else 0
  seam=np.maximum(groove(x+stagger,rx,.040 if kind=='tile' else .065),groove(y,ry,.040 if kind=='tile' else .10))
  h-=seam*(1.5 if kind=='tile' else 2.3); tint-=seam*.35
  if kind=='tile': rough=.29+.32*seam+.08*cloud
  else: tint+=grain*.11
 if kind=='wood':
  rings=np.sin(2*np.pi*(x*16+.7*noise(3)+.23*np.sin(y*2*np.pi)))
  narrow=np.power((rings+1)/2,8)
  lines=np.sin(2*np.pi*(x*109+noise(6)*2+y))
  tint+=.095*rings-.125*narrow+.025*lines;h+=.25*rings+.14*lines
  rough[:]=.48
 if kind in ('stone','asphalt','soil'):
  speck=np.clip(grain*3,-1,1)
  tint+=speck*.11; h+=speck*.27
  if kind=='asphalt': rough=.17+.39*np.clip(.51+cloud,0,1)
 if kind in ('glass','iron','rust','plastic'):
  scratch=groove(x*7+y+noise(4)*.02,12,.018)*np.maximum(0,cloud)
  h-=scratch*.38;tint+=scratch*.07
  rough=(.12 if kind=='glass' else .43)+cloud*.075+scratch*.25
  if kind=='iron': metal=np.clip(.35+.42*np.clip(cloud,0,1),0,1)
  if kind=='rust': metal=np.clip(.84-.9*np.clip((cloud+.17)*1.45,0,1),0,1)
 if kind in ('weave','paper'):
  weave=np.sin(x*2*np.pi*96)*np.cos(y*2*np.pi*96)*.5+.5*np.sin(y*2*np.pi*48)
  grain_amount=.065 if kind=='weave' else .027
  tint+=weave*grain_amount; h+=weave*(grain_amount*2)
 if kind=='roof':
  scallop=(np.cos(x*2*np.pi*5)+1)*.5
  lip=groove(y,3,.065)
  tint+=scallop*.11-lip*.2;h+=scallop*3.-lip*.9
 if kind=='leaf':
  veins=np.maximum(groove(x,1,.02),groove(y-np.abs(x-.5)*.70,12,.032))*.8
  h+=veins*.4; tint+=veins*.23
 rgb=np.array([int(color[i:i+2],16) for i in (0,2,4)])
 albedo=np.clip(np.rint(rgb[None,None,:]*(1+tint[:,:,None])),0,255).astype(np.uint8)
 # Monochrome-height derivatives wrap across each edge of the tile.
 h=gaussian_filter(h,.55,mode='wrap')
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))*.55*n/512
 dy=(np.roll(h,-1,0)-np.roll(h,1,0))*.55*n/512
 normals=np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
 normals/=np.linalg.norm(normals,axis=2)[:,:,None]
 tex=root/'textures'/name;tex.mkdir(parents=True,exist_ok=True)
 Image.fromarray(albedo).save(tex/'albedo.png',optimize=True)
 Image.fromarray(np.uint8(np.rint((normals*.5+.5)*255))).save(tex/'normal.png')
 Image.fromarray(np.uint8(np.rint(np.clip(rough,0,1)*255))).save(tex/'roughness.png')
 ids=['albedo','normal','roughness']
 if metal is not None:
  ids.append('metallic')
  Image.fromarray(np.uint8(np.rint(metal*255))).save(tex/'metallic.png')
 refs='\n'.join('[ext_resource type="Texture2D" path="res://assets/materials/textures/%s/%s.png" id="%s"]'%(name,i,i) for i in ids)
 metallic='\nmetallic = 1.0\nmetallic_texture = ExtResource("metallic")' if metal is not None else ''
 glass='\ntransparency = 1\nalbedo_color = Color(1, 1, 1, 0.38)' if kind=='glass' else ''
 (root/(name+'.tres')).write_text('[gd_resource type="StandardMaterial3D" load_steps=%d format=3]\n\n%s\n\n[resource]\nresource_name = "%s"\nalbedo_texture = ExtResource("albedo")\nnormal_enabled = true\nnormal_texture = ExtResource("normal")\nroughness_texture = ExtResource("roughness")%s%s\n'%(len(ids)+1,refs,name,metallic,glass))
if __name__=='__main__':
 ap=argparse.ArgumentParser(); ap.add_argument('--size',type=int,default=512);ap.add_argument('--out',type=Path,default=DEFAULT); args=ap.parse_args()
 for i,(name,(kind,col)) in enumerate(SURFACES.items()):
  make(name,kind,col,args.out,args.size,i+1347)
