"""Run with Blender 4.x: blender -b -P tools/model_items.py [-- item_id ...]."""
import bpy, math, sys
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from item_data import ITEMS
from math import pi, sin, cos
s=bpy.context.scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
s.render.engine="BLENDER_WORKBENCH"
sh=s.display.shading
sh.light='STUDIO'
sh.studio_light='paint.sl'
sh.color_type='MATERIAL'
sh.show_cavity=True
sh.cavity_type='WORLD'
sh.cavity_ridge_factor=1.1
sh.cavity_valley_factor=1.3
sh.show_shadows=True
sh.show_specular_highlight=True
s.display.render_aa='8'
s.render.resolution_x=s.render.resolution_y=1024
s.render.resolution_percentage=100
s.render.film_transparent=True
s.render.image_settings.color_mode='RGBA'
s.view_settings.view_transform='Standard'
bpy.ops.object.camera_add()
cam=bpy.context.object
cam.name="Catalogue Camera"
s.camera=cam
cam.data.type='ORTHO'
cam.data.clip_start=.001
palette={'black':'252b2a','ink':'233a3c','rubber':'303635','ash':'747c74','silver':'c4c7b8','metal':'889991','gold':'b99b5c','paper':'dfd4b6','white':'ede6d7','red':'a13f32','blue':'34667a','yellow':'c9a249','green':'456d5c','navy':'2c4857','olive':'666e50','brown':'866248','amber':'cc8657','glass':'759c9c','wood':'856855'}
materials={}
def material(name):
 if name not in materials:
  h=palette.get(name,name)
  rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
  color=tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
  m=bpy.data.materials.new(name)
  m.diffuse_color=color; m.use_nodes=True
  p=m.node_tree.nodes.get('Principled BSDF')
  p.inputs['Base Color'].default_value=color
  p.inputs['Metallic'].default_value=.72 if name in ('gold','silver','metal') else .05
  p.inputs['Roughness'].default_value=.25 if name=='glass' else .59
  m.use_fake_user=True; materials[name]=m
 return materials[name]
parts=[]
def part(o,name,mat):
 o.name=name
 o.data.materials.append(material(mat)); parts.append(o)
 return o
def bevel(o,v):
 if v>0:
  b=o.modifiers.new('Rounded manufactured edges','BEVEL'); b.width=v; b.segments=3
  n=o.modifiers.new('Corner normals','WEIGHTED_NORMAL'); n.keep_sharp=True
def box(name,loc,size,col,r=.03):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=part(bpy.context.object,name,col)
 o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bevel(o,min(r,min(size)*.44))
 return o
def cylinder(name,a,b,r,col,r2=None,n=32):
 a,b=Vector(a),Vector(b); v=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=v.length,location=(a+b)/2)
 o=part(bpy.context.object,name,col)
 o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
 bevel(o,min(r*.06,v.length*.14))
 for p in o.data.polygons:
  p.use_smooth=(len(p.vertices)==4)
 return o
def tube(name,points,r,c):
 cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.resolution_u=12
 sp=cu.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
 for p,xyz in zip(sp.bezier_points,points):
  p.co=xyz; p.handle_left_type=p.handle_right_type='AUTO'
 cu.bevel_depth=r; cu.bevel_resolution=3; cu.use_fill_caps=True
 ob=bpy.data.objects.new(name,cu); bpy.context.collection.objects.link(ob)
 return part(ob,name,c)
def ring(name,x,y,z,rad,wire,col,ys=1):
 bpy.ops.mesh.primitive_torus_add(location=(x,y,z),major_segments=36,minor_segments=10,major_radius=rad,minor_radius=wire)
 o=part(bpy.context.object,name,col); o.scale.y=ys
 for p in o.data.polygons: p.use_smooth=True
 return o
def label(text,x,y,z,size,col,center=True):
 cu=bpy.data.curves.new('Letterpress','FONT'); cu.body=text; cu.size=size; cu.align_x='CENTER' if center else 'LEFT'; cu.align_y='CENTER'
 ob=bpy.data.objects.new('Print '+text,cu); bpy.context.collection.objects.link(ob); ob.location=(x,y,z)
 return part(ob,'Print '+text,col)
def sphere(name,loc,scale,col):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc)
 o=part(bpy.context.object,name,col); o.scale=scale
 for p in o.data.polygons: p.use_smooth=True
 return o
def disc(x,y,z,r,h,col):
 return cylinder('Stamped disc',(x,y,z),(x,y,z+h),r,col)
def bar(x,y,z,w,h,col):
 return box('Ink or inlay',(x,y,z),(w,h,.006),col,0)
def along(x1,x2,r,c,y=0,z=.13,r2=None):
 return cylinder('Machined barrel',(x1,y,z),(x2,y,z),r,c,r2)
def face(name,x,y,z,w,h,col):
 return box(name,(x,y,z),(w,h,.012),col,.004)
def make(id):
 if id.endswith('_key'):
  keys=['classroom_key','teachers_office_key','infirmary_key','archive_key','emergency_gate_key','locker_key','master_key']
  k=keys.index(id); c=['gold','metal','silver','brown','metal','silver','gold'][k]
  ring('Bow',-.48,0,.07,.196,.058,c,1+.045*k)
  box('Milled blade',(.15,.023,.075),(1,.13,.092),c)
  box('Shoulder',(-.18,0,.075),(.12,.22,.10),c)
  for i in range(4):
   h=.13+.045*((i+3*k)%3); box('Key bitting',(.24+i*.1,-h*.47,.078),(.098,h,.09),c,.008)
  box('Cut channel',(.19,.061,.123),(.80,.018,.006),'ash',0)
  if k in (0,1,2,6):
   ring('Jump ring',-.72,.12,.10,.12,.017,'silver')
   box('Room tag',(-.89,.34,.067),(.48,.30,.085),['gold','red','white','black','black','black','olive'][k])
   label(['XII','GURU','UKS','','','','SB'] [k],-.89,.34,.114,.129,'ink' if k in (0,2) else 'white')
 elif id.startswith('fuse_') or id=='battery':
  is_cell=id=='battery'; c={'battery':'olive','fuse_red':'red','fuse_blue':'blue','fuse_yellow':'yellow'}[id]
  along(-.58,.58,.223,c,z=.23)
  for a,b in ((-.65,-.48),(.48,.65)): along(a,b,.231,'silver',z=.23)
  for x in (-.46,.43): along(x,x+.026,.227,'ink',z=.23)
  if is_cell:
   along(.63,.72,.098,'metal',z=.23)
   face('Printed sleeve',0,0,.455,.56,.18,'paper'); label('SEL  +',0,0,.465,.12,'ink')
  else:
   face('Symbol tab',0,0,.457,.37,.24,'paper')
   label({'fuse_red':'/\\','fuse_blue':'O','fuse_yellow':'[ ]'}[id],0,0,.467,.2,'ink')
 elif id=='flashlight':
  along(-.78,.34,.18,'black',z=.27)
  along(.26,.55,.19,'black',z=.27,r2=.31)
  along(.53,.84,.31,'rubber',z=.27)
  along(.815,.86,.29,'silver',z=.27); along(.856,.87,.24,'glass',z=.27)
  for x in [-.76,-.70,-.6,-.48,-.36,-.24,-.12,.56,.63,.70]: along(x,x+.025,.188 if x<0 else .315,'ash' if x==.63 else 'rubber',z=.27)
  box('Thumb switch',(.13,0,.445),(.22,.13,.065),'red')
  tube('Lanyard',[(-.77,.03,.26),(-1.06,.06,.14),(-1.21,-.12,.04),(-1.06,-.21,.05),(-.74,-.03,.26)],.019,'black')
 elif id=='screwdriver' or id=='microphone':
  if id=='screwdriver':
   along(-.95,-.12,.16,'black',z=.2,r2=.185)
   for x in [-.88,-.76,-.64,-.52,-.4,-.28]: along(x,x+.052,.175,'red',z=.2)
   along(-.14,.02,.20,'red',z=.2); along(0,.88,.048,'silver',z=.2)
   box('Slotted tip',(.93,0,.20),(.15,.123,.047),'metal')
  else:
   along(-.79,.45,.112,'black',z=.24,r2=.167)
   sphere('Steel grille',(.5,0,.24),(.235,.235,.235),'metal')
   for i in range(10):
    x=.29+i*.044; r=math.sqrt(max(.001,.24**2-(x-.50)**2))
    along(x,x+.014,r,'ink',z=.24)
   box('Talk switch',(-.09,0,.388),(.18,.079,.035),'ash')
   along(-.85,-.78,.1,'silver',z=.24)
 elif id=='walkie_talkie' or id=='voice_recorder':
  radio=id=='walkie_talkie'
  box('Shell',(0,0,.18),(.68,1.03,.32),'rubber' if radio else 'metal',.12)
  box('LCD surround',(0,.22,.34),(.52,.30,.026),'ink')
  face('LCD',0,.22,.36,.43,.20,'olive'); label('CH 03' if radio else '00:13',0,.22,.37,.104,'paper')
  for i in range(5): box('Speaker grille',(0,-.12-i*.065,.35),(.45,.026,.018),'ash')
  if radio:
   cylinder('Whip antenna',(-.20,.48,.18),(-.20,1.14,.18),.055,'black',.026)
   cylinder('Volume knob',(.14,.43,.18),(.14,.61,.18),.107,'black')
   box('PTT',(-.35,.14,.19),(.072,.32,.11),'red')
  else:
   disc(0,-.03,.353,.065,.01,'red')
   for x in [-.19,.19]: sphere('Microphone capsule',(x,.49,.18),(.12,.13,.12),'ink')
 elif id.startswith('smartphone'):
  c={'smartphone_raka':'black','smartphone_reski':'green','smartphone_akbar':'red'}[id]
  box('Protective case',(0,0,.052),(.75,1.45,.103),c,.078)
  box('Raised bezel',(0,0,.10),(.709,1.39,.034),'black')
  face('Sleeping display',0,-.005,.121,.641,1.25,'ink')
  label('00:00',0,.30,.132,.18,'white'); label('JUMAT',0,.12,.132,.065,'silver')
  box('Ear speaker',(0,.621,.135),(.11,.022,.008),'ash'); disc(.11,.62,.13,.018,.01,'glass')
  bar(0,-.55,.137,.16,.013,'paper')
 elif id in ('access_card','library_card'):
  access=id=='access_card'
  box('Laminated PVC',(0,0,.025),(1.5,.93,.048),'paper')
  face('Header band',0,.319,.056,1.46,.23,'green' if access else 'navy')
  label('SMA NUSA BANGSA',0,.32,.064,.126,'white')
  face('Identity panel',-.48,-.12,.055,.34,.43,'ash')
  disc(-.48,-.075,.066,.07,.005,'ink'); box('Portrait',(-.48,-.238,.069),(.19,.16,.008),'ink')
  label('KARTU AKSES' if access else 'PERPUSTAKAAN',.20,.003,.068,.107,'ink')
  for i in range(26): bar(-.20+i*.032,-.22,.071,.009+.007*(i%3),.10,'ink')
 elif id in ('attendance_book','school_yearbook','assignment_folder','black_notebook'):
  c={'attendance_book':'green','school_yearbook':'navy','assignment_folder':'amber','black_notebook':'black'}[id]
  t=.072 if id=='assignment_folder' else .15
  box('Book boards',(0,0,.025),(1,1.37,.045),c)
  box('Trimmed leaves',(.015,0,t/2+.04),(.934,1.30,t),'paper')
  box('Upper board',(0,0,t+.061),(1,1.37,.05),c)
  box('Spine',(-.472,0,t*.5+.04),(.068,1.36,t+.07),c)
  z=t+.09
  bar(-.39,0,z,.015,1.26,'gold')
  face('Imprint',.026,.19,z,.71,.34,'paper' if id!='school_yearbook' else 'gold')
  text={'attendance_book':'ABSENSI','school_yearbook':'TAHUNAN','assignment_folder':'TUGAS RPL','black_notebook':'LARAS'}
  label(text[id],.023,.224,z+.013,.117,'ink')
  label('SMA NUSA BANGSA',.023,.105,z+.013,.048,'ink')
  for y in [-.43,-.47]: bar(.035,y,z,.41,.013,'gold')
  if id=='black_notebook': bar(.33,0,z+.012,.04,1.34,'brown')
 elif id in ('damaged_photo','original_photo'):
  box('Silver halide print',(0,0,.018),(1.54,1.02,.03),'paper')
  face('School wall',0,.018,.04,1.40,.82,'olive')
  face('School eaves',0,.32,.05,1.39,.13,'navy')
  for i in range(5): face('Window',-.52+i*.265,.16,.055,.16,.22,'ink')
  for row in range(2):
   for i in range(8-row):
    x=-.58+i*.164+row*.08; y=-.20+row*.18
    face('School uniform',x,y,.061+(1-row)*.007,.126,.13,'paper'); disc(x,y+.095,.071,.042,.004,'brown')
  label('XII  /  NUSA BANGSA',.23,-.445,.044,.048,'ink')
  if id=='damaged_photo':
   for i in range(5): face('Scorch mark',.67-i*.028,.40+i*.008,.083,.13,.15-i*.013,'brown')
   tube('Crease',[(-.72,-.34,.086),(-.31,-.13,.086),(.12,.12,.086),(.75,.43,.086)],.006,'paper')
 elif id=='cassette_tape':
  box('Cassette housing',(0,0,.10),(1.42,.91,.19),'black')
  face('Paper label',0,.07,.204,1.29,.56,'paper')
  bar(0,.285,.215,1.26,.042,'red'); label('A     ARSIP SUARA',0,.204,.217,.088,'ink')
  for x in [-.34,.34]:
   disc(x,.01,.216,.145,.012,'ink'); ring('Spool',x,.01,.23,.086,.023,'silver')
  face('Tape window',0,.01,.217,.27,.13,'brown')
  for x in [-.59,.59]:
   for y in [-.365,.353]: disc(x,y,.204,.025,.01,'metal')
  for x in [-.34,0,.34]: disc(x,-.35,.204,.048,.01,'ink')
 elif id in ('medicine_box','padlock','backpack'):
  if id=='medicine_box':
   box('Enamel case',(0,0,.21),(1.32,.83,.40),'paper',.09)
   box('Hinged lid',(0,0,.425),(1.34,.85,.11),'white')
   bar(0,0,.485,.51,.159,'green'); bar(0,0,.485,.159,.49,'green')
   for x in [-.37,.37]: box('Catch',(x,-.425,.30),(.119,.05,.14),'metal')
   tube('Handle',[(-.24,.41,.20),(-.23,.60,.20),(.23,.60,.20),(.24,.41,.20)],.027,'metal')
  elif id=='padlock':
   box('Laminated lock body',(0,-.14,.15),(.78,.65,.29),'gold',.07)
   tube('Steel shackle',[(-.255,.12,.14),(-.255,.55,.14),(0,.76,.14),(.255,.55,.14),(.255,.12,.14)],.071,'silver')
   face('Keyway',0,-.14,.301,.052,.161,'ink');disc(0,-.05,.30,.061,.006,'ink')
   for x in [-.28,.28]: disc(x,-.34,.30,.028,.007,'metal')
  else:
   box('Canvas pack',(0,0,.22),(.97,1.40,.42),'olive',.19)
   box('Outer pocket',(0,-.26,.44),(.78,.66,.19),'green',.08)
   bar(0,-.076,.543,.54,.026,'black')
   for x in [-.32,.32]:
    box('Compression strap',(x,.25,.425),(.080,.52,.044),'rubber')
    box('Buckle',(x,.21,.459),(.13,.13,.03),'metal')
   face('Sewn label',0,-.27,.551,.27,.14,'paper'); label('RPL',0,-.27,.56,.089,'ink')
   tube('Carry loop',[(-.19,.63,.20),(-.15,.83,.20),(.15,.83,.20),(.19,.63,.20)],.033,'rubber')
 elif id=='emergency_lever':
  box('Mounting plate',(0,0,.06),(.60,1.07,.115),'metal')
  for x in [-.21,.21]:
   for y in [-.42,.42]: disc(x,y,.122,.04,.011,'silver')
  cylinder('Axis',(-.25,-.17,.25),(.25,-.17,.25),.13,'ink')
  cylinder('Handle',(0,-.17,.25),(0,.35,.70),.063,'silver')
  cylinder('Red grip',(-.27,.35,.70),(.27,.35,.70),.094,'red')
 elif id=='water_bottle':
  along(-.61,.29,.24,'glass',z=.24)
  along(.28,.50,.24,'glass',z=.24,r2=.098)
  along(.48,.65,.113,'navy',z=.24)
  along(-.26,.14,.245,'paper',z=.24)
  for x in [-.54,-.47,-.40,.52,.56,.60]: along(x,x+.014,.247 if x<0 else .117,'glass' if x<0 else 'navy',z=.24)
  face('Name strip',-.05,0,.49,.38,.127,'paper');label('AKBAR',-.05,0,.501,.086,'ink')
 else:
  titles={'fire_report':'LAPORAN INSIDEN','witness_statement_01':'BERITA ACARA I','witness_statement_02':'BERITA ACARA II','witness_statement_03':'BERITA ACARA III','electrical_diagram':'SKEMA PANEL','old_newspaper':'WARTA DAERAH','mystery_note':'UNTUK RAKA'}
  c='paper' if id!='old_newspaper' else 'c7b592'
  box('Folded sheet',(0,0,.014),(1.02,1.44,.024),c)
  z=.033
  label('SMA NUSA BANGSA' if id!='old_newspaper' else 'EDISI JAWA BARAT',0,.58,z,.049,'ink')
  label(titles[id],0,.446,z,.105,'ink')
  bar(0,.34,z,.85,.015,'ink')
  if id=='electrical_diagram':
   for i,symbol in enumerate(['/\\','O','[ ]']):
    x=-.30+i*.30; face('Circuit block',x,.02,z+.003,.20,.20,'ink')
    label(symbol,x,.02,z+.014,.13,'white');bar(x,-.16,z,.01,.15,'ink')
   bar(0,-.235,z,.60,.012,'ink')
  elif id=='old_newspaper':
   for j in range(2):
    for i in range(17): bar(-.225+j*.45,.247-i*.044,z,.382-(i%5)*.012,.012,'ink')
  else:
   for i in range(9):
    w=.81-(i%4)*.072; bar(-.41+w/2,.24-i*.066,z,w,.010,'ash')
   if id.startswith('witness') or id=='fire_report':
    ring('Seal',.25,-.42,z+.002,.11,.009,'red')
    label('ARSIP',.25,-.42,z+.013,.065,'red')
   else: bar(-.12,-.45,z,.51,.025,'red')

requested=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
for id,title,desc,kind,size in ITEMS:
 if requested and id not in requested: continue
 parts.clear()
 make(id)
 bpy.ops.object.select_all(action='DESELECT')
 for ob in parts: ob.select_set(True)
 bpy.context.view_layer.objects.active=parts[0]
 bpy.ops.object.convert(target='MESH')
 bpy.ops.object.join()
 ob=bpy.context.object; ob.name=id
 bpy.context.scene.cursor.location=(0,0,0)
 bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bounds=[Vector(v) for v in ob.bound_box]
 lo,hi=bounds[0],bounds[6]
 size=float(size)
 from mathutils import Matrix
 factor=size/max(hi-lo)
 center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 ob.data.transform(Matrix.Scale(factor,4) @ Matrix.Translation(-center))
 points=[v.co for v in ob.data.vertices]
 target=Vector((0,0,(hi.z-lo.z)*factor*.5))
 direction=Vector((.70,-1.05,1.72)).normalized()
 cam.location=target+direction*size*3
 cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
 bpy.context.view_layer.update()
 coords=[cam.matrix_world.inverted() @ v for v in points]
 x1,x2=min(v.x for v in coords),max(v.x for v in coords)
 y1,y2=min(v.y for v in coords),max(v.y for v in coords)
 cam.location += cam.rotation_euler.to_matrix() @ Vector(((x1+x2)/2,(y1+y2)/2,0))
 cam.data.ortho_scale=max(x2-x1,y2-y1)*1.13
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/'items'/'models'/(id+'.glb')),use_selection=True,export_animations=False,export_yup=True)
 s.render.filepath=str(ROOT/'assets'/'items'/'masters'/(id+'.png'))
 bpy.ops.render.render(write_still=True)
 bpy.data.objects.remove(ob,do_unlink=True)
 bpy.ops.outliner.orphans_purge(do_recursive=True)
 print('CATALOGUE ITEM COMPLETE: '+id,flush=True)
