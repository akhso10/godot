"""Rebuild the school GLB kit with blender -b -P tools/build_school_models.py."""
import math
import os
import random
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'models', 'environment'))
os.makedirs(ROOT, exist_ok=True)
random.seed(1747)
bpy.ops.wm.read_factory_settings(use_empty=True)
mat = bpy.data.materials.new('Cat, kayu dan besi')
mat.use_nodes = True
color = mat.node_tree.nodes.new('ShaderNodeVertexColor')
color.layer_name = 'Pigmen'
shader = mat.node_tree.nodes.get('Principled BSDF')
mat.node_tree.links.new(color.outputs['Color'], shader.inputs['Base Color'])
shader.inputs['Roughness'].default_value = 0.77

wood='#805737'; lip='#b79165'; iron='#354141'; dark='#21292b'; cream='#c7c2a6'
green='#497365'; moss='#688879'; red='#933e35'; blue='#426276'; tile='#87908b'; white='#d9d8c4'; brass='#aa935d'
vertices=[]; faces=[]; shades=[]
def model(pts, fs, pigment):
    offset = len(vertices)
    vertices.extend((x,-z,y) for x,y,z in pts)
    rgb=[int(pigment[i:i+2],16)/255 for i in (1,3,5)]
    linear=[((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb]
    for f in fs:
        faces.append([k+offset for k in f]); shades.append(linear+[1.0])
def box(x,y,z,w,h,d,c,angle=0):
    a=math.radians(angle); s=math.sin(a); co=math.cos(a)
    pts=[]
    for sy in [-1,1]:
        for sz,sx in [(-1,-1),(-1,1),(1,1),(1,-1)]:
            xx=sx*w/2; zz=sz*d/2
            pts.append((x+xx*co+zz*s,y+sy*h/2,z+zz*co-xx*s))
    model(pts,[[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]],c)
def rod(a,b,r,c,r2=None,n=10):
    start=Vector(a); end=Vector(b); axis=(end-start).normalized()
    side=axis.cross(Vector((1,0,0)) if abs(axis.x)<.8 else Vector((0,0,1))).normalized()
    fwd=axis.cross(side)
    pts=[p+(side*math.cos(i*math.tau/n)+fwd*math.sin(i*math.tau/n))*rad for p,rad in [(start,r),(end,r if r2 is None else r2)] for i in range(n)]
    model(pts,[list(reversed(range(n))),list(range(n,n*2))]+[[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)],c)
def save(name):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    attr=mesh.color_attributes.new(name='Pigmen',type='FLOAT_COLOR',domain='CORNER')
    for i,poly in enumerate(mesh.polygons):
        for loop in poly.loop_indices: attr.data[loop].color=shades[i]
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    mesh.materials.append(mat); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,name+'.glb'),use_selection=True,export_yup=True,export_animations=False)
    bpy.data.objects.remove(ob,do_unlink=True); bpy.data.meshes.remove(mesh)
    vertices.clear(); faces.clear(); shades.clear()

def table(w,d,h=0.75,frame=iron,top=wood):
    for x in (-w*.43,w*.43):
        for z in (-d*.39,d*.39): box(x,h*.5,z,.04,h,.04,frame)
        box(x,.22,0,.035,.04,d*.8,frame)
    box(0,h-.08,0,w-.06,.09,d-.04,lip)
    box(0,h,0,w,.045,d,top)
def chair():
    table(.44,.43,.44)
    for x in [-.18,.18]: box(x,.60,.18,.035,.41,.035,iron)
    box(0,.72,.18,.43,.16,.038,wood)
def desk():
    table(1.12,.58)
    box(0,.54,-.025,.9,.025,.45,iron)
def cupboard(w,h,d,c=green):
    box(0,h/2,0,w,h,d,c)
    for x in [-.24,.24]:
        box(x*w,h*.51,-d/2,w*.47,h*.92,.032,moss)
        box(x*w*.30,h*.49,-d/2-.031,.019,.12,.03,brass)
        for j in range(3): box(x*w,h*.84+.029*j,-d/2-.023,w*.24,.012,.015,iron)
def shelf(books=True):
    w=1.46; h=1.95; d=.42
    for x in [-.7,.7]: box(x,h/2,0,.055,h,d,wood)
    box(0,h/2,.19,w,h,.035,'#5f4835')
    rng=random.Random(20)
    for i in range(5):
        y=.08+i*.46; box(0,y,0,w,.045,d,lip)
        if books and i<4:
            x=-.64
            while x<.59:
                bw=rng.uniform(.044,.093); bh=rng.uniform(.23,.386)
                pigment=rng.choice([green,red,blue,cream,wood,iron,brass])
                box(x+bw/2,y+.025+bh/2,-.035,bw-.005,bh,.27,pigment)
                box(x+bw/2,y+.092,-.174,bw*.8,.016,.008,cream)
                x+=bw
def monitor():
    box(0,.03,0,.30,.035,.18,dark); box(0,.12,0,.07,.2,.06,iron)
    box(0,.30,0,.50,.30,.07,dark); box(0,.30,-.041,.46,.25,.015,'#618178')
def clock():
    rod((0,0,.03),(0,0,-.02),.26,iron,n=32); rod((0,0,-.022),(0,0,-.032),.233,cream,n=32)
    for i in range(12):
        a=i*math.tau/12; x=math.sin(a); y=math.cos(a)
        rod((x*.18,y*.18,-.039),(x*.205,y*.205,-.039),.007,iron,n=5)
    box(0,.069,-.045,.014,.152,.014,iron)
    rod((0,0,-.052),(.115,.063,-.052),.009,iron)
def planter(tree=False):
    r=.43 if tree else .24
    rod((0,0,0),(0,r*1.4,0),r*.67,wood,r,n=12)
    rod((0,r*1.38,0),(0,r*1.45,0),r*1.07,lip,n=12)
    height=3.6 if tree else .70
    rod((0,r*1.45,0),(.045,height,0),r*.25,wood,r*.17)
    length=2.1 if tree else .54
    for j in range(17 if tree else 12):
        a=j*2.399; bx=math.cos(a); bz=math.sin(a); reach=length*(.68+.32*math.sin(j*4.13)**2); top=height-.18*math.sin(j*.54)**2
        side=Vector((-bz,0,bx))*reach*.12
        pts=[Vector((.045,top,0)),Vector((bx*reach*.44,top+reach*.38,bz*reach*.44))+side,Vector((bx*reach*.61,top+reach*.42,bz*reach*.61)),Vector((bx*reach,top+reach*.13,bz*reach)),Vector((bx*reach*.44,top+reach*.38,bz*reach*.44))-side]
        for k in [[0,1,2],[1,3,2],[0,2,4],[4,2,3]]:
            model(pts,[k,list(reversed(k))],['#405b3c','#56704b','#334c3b'][j%3])
def door(c):
    box(.49,1.01,0,.98,2.02,.065,c)
    for y in [.52,1.35]: box(.49,y,-.037,.76,.63,.019,lip if c==wood else moss)
    box(.86,.94,-.06,.045,.16,.026,brass); box(.81,.99,-.094,.12,.022,.024,iron)
def window():
    for x in [-.75,0,.75]: box(x,.55,0,.043,1.1,.08,iron)
    for y in [0,.55,1.1]: box(0,y,0,1.54,.045,.08,iron)
    for x in [-.38,.38]: box(x,.56,.026,.69,1.01,.02,'#4c6366')
def lamp(emergency=False):
    if emergency:
        box(0,0,0,.29,.14,.10,iron); box(0,0,-.06,.21,.105,.04,'#e78a56')
    else:
        box(0,0,0,1.3,.075,.26,iron)
        for z in [-.068,.068]: rod((-.6,-.055,z),(.6,-.055,z),.025,white)
def bed():
    table(.88,1.86,.47,iron,green); box(0,.55,0,.88,.13,1.86,white)
    box(0,.62,.65,.65,.10,.31,cream)
    for z in [-.96,.96]:
        for x in [-.43,.43]: box(x,.45,z,.04,.90,.04,iron)
        box(0,.86,z,.89,.042,.04,iron)
def console():
    table(1.75,.7)
    box(0,.83,0,1.08,.12,.52,dark)
    for x in range(13):
        box(-.45+x*.075,.897,-.07,.012,.012,.20,iron)
        box(-.45+x*.075,.912,-.09+.048*math.sin(x),.045,.018,.035,cream)
        for j in [0,1,2]: rod((-.45+x*.075,.894,.08+j*.06),(-.45+x*.075,.917,.08+j*.06),.014,[red,brass,green][j])
def crate():
    box(0,.24,0,.67,.48,.52,'#99784c')
    box(0,.244,0,.09,.489,.53,'#bc9c65')
def breaker():
    box(0,.78,0,.8,1.5,.22,'#62716a')
    box(0,.81,-.122,.7,1.23,.04,'#374742')
    for j in range(3):
        for i in range(4): 
            x=-.22+i*.145; y=.49+j*.31
            box(x,y,-.16,.114,.20,.048,cream)
            box(x,y,-.19,.065,.078,.043,red if i==0 else dark)
def stage_curtain():
    for i in range(25):
        x=-2.4+i*.2
        box(x,1.25,.055*math.sin(i*1.9),.22,2.5,.12, ['#723734','#833e3c','#90443d'][i%3])
def drawers():
    box(0,.7,0,.7,1.4,.56,iron)
    for i in range(4):
        y=.19+i*.34
        box(0,y,-.287,.66,.30,.036,moss)
        box(0,y+.05,-.312,.16,.057,.02,cream)
        box(0,y-.018,-.332,.11,.018,.037,iron)
def toilet():
    box(0,.53,.22,.4,.37,.14,white); rod((0,.04,0),(0,.28,0),.11,white,.21)
    rod((0,.28,-.06),(0,.40,-.06),.23,cream,.25); rod((0,.4,-.06),(0,.409,-.06),.15,'#737c76')
def sink():
    box(0,.79,0,.69,.13,.45,white); box(0,.86,-.01,.49,.01,.29,tile)
    rod((0,.86,.17),(0,1.01,.17),.021,iron);rod((0,1.01,.17),(0,1.01,.09),.018,iron)
    box(0,.42,.12,.15,.72,.13,cream)
def speaker():
    box(0,.36,0,.40,.72,.33,dark)
    for y,r in [(.24,.14),(.55,.073)]:
        rod((0,y,-.16),(0,y,-.185),r,iron,n=16)
        rod((0,y,-.187),(0,y,-.195),r*.4,dark,n=12)
def flag():
    rod((0,0,0),(0,6.5,0),.06,tile,.035)
    for i in range(9):
        x=.09+i*.13; z=math.sin(i*.7)*.1
        for j,c in [(0,white),(1,red)]: box(x,5.85+j*.33-.035*math.sin(i*.57),z,.15,.34,.032,c)
def gate(w=3.4,h=2.1):
    for x in [-w/2,w/2]: box(x,h*.5,0,.10,h,.12,iron)
    for y in [.16,1.55]: box(0,y,0,w,.095,.12,green)
    for i in range(17):
        x=(i/16-.5)*w; q=h*(.88+.09*math.cos(i*.39))
        box(x,q/2,0,.038,q,.038,green);rod((x,q,0),(x,q+.09,0),.053,green,.001,n=4)
def board():
    box(0,0,0,1.65,.9,.08,lip);box(0,0,-.047,1.56,.81,.04,'#3e6654')
    for i in range(6):
        box(-.56+(i%3)*.48,.14-(i//3)*.29,-.078,.22,.25,.009,[cream,white,brass][i%3])
def classroom_board():
    box(0,0,0,2.7,1.04,.09,lip); box(0,0,-.055,2.59,.93,.02,'#35534a')
    box(0,-.54,-.04,2.74,.05,.16,wood)
    for i in range(5):box(-.72+i*.23,-.13+.03*math.sin(i),-.069,.135,.007,.01,'#81958b')
def desk_lamp():
    rod((0,0,0),(0,.028,0),.135,iron)
    rod((0,.026,0),(.035,.30,0),.017,iron)
    rod((.035,.30,0),(-.085,.38,-.04),.02,iron)
    rod((-.085,.38,-.04),(-.10,.29,-.08),.045,green,.115)
def generator():
    box(0,.23,0,.92,.36,.46,red); box(.07,.54,0,.52,.27,.41,iron)
    for x in [-.5,.5]:
        for z in [-.28,.28]:box(x,.35,z,.045,.7,.045,dark)
        box(x,.68,0,.045,.045,.6,dark)
    for z in [-.28,.28]:box(0,.69,z,1,.048,.048,dark)
def rodline(x,y,z,w,c): box(x,y,z,w,.025,.04,c)
def bench():
    table(1.7,.36,.44)
def stair():
    for i in range(24):
        h=(i+1)*.15; box(0,h/2,-(i+.5)*.355,2.35,h,.355,tile)
        box(0,h+.003,-i*.355-.038,2.35,.008,.068,cream)
def railing():
    for x in [-.97,0,.97]:box(x,.49,0,.045,.98,.045,iron)
    for y in [.31,.63,.98]:box(0,y,0,2,.047,.047,green)
def podium():
    box(0,.06,0,.71,.12,.51,wood);box(0,.57,0,.52,1,.32,wood);box(0,1.1,0,.74,.095,.50,lip)
def stage_trophy():
    box(0,.035,0,.18,.07,.18,dark);rod((0,.07,0),(0,.24,0),.035,brass)
    rod((0,.24,0),(0,.41,0),.06,brass,.13,n=12)
def storage_rack(): shelf(False)
def fan():
    rod((0,0,0),(0,-.24,0),.035,iron);rod((0,-.24,0),(0,-.30,0),.12,green)
    for i in range(3):
        a=i*120; box(math.cos(math.radians(a))*.36,-.265,math.sin(math.radians(a))*.36,.66,.026,.12,lip,-a)
def counter():
    table(1.8,.75,.82)
    for x in [-.85,.85]:
        for z in [-.33,.33]: box(x,1.09,z,.032,.52,.032,iron)
    box(0,1.36,0,1.83,.035,.75,iron)
    for i in range(3):rod((-.55+i*.55,.85,0),(-.55+i*.55,.92,0),.19,cream,.16)
def bulletin_frame():
    box(0,0,0,.5,.36,.06,wood); box(0,0,-.034,.44,.30,.012,cream)
    box(0,0,-.045,.38,.24,.01,blue)
def curtain():
    for i in range(13):
        box(-.6+i*.10,.91,.048*math.sin(i*1.9),.11,1.66,.04,[moss,green][i%2])
    rod((-.67,1.76,0),(.67,1.76,0),.018,iron)
def doorwall(): 
    for x in [-1.22,1.22]:box(x,1.5,0,1.56,3,.18,cream)
    box(0,2.55,0,.90,.90,.18,cream)
def wallwindow():
    box(0,.52,0,3,1.04,.18,green);box(0,2.63,0,3,.74,.18,cream)
    for x in [-1.12,1.12]:box(x,1.65,0,.76,1.25,.18,cream)
def roof():
    for x in [-1,1]:
        for j in range(8):box(x*(j*.18+.09),.8-j*.088,0,.20,.12,2.1,red)
def vent():
    for i in range(6):box(0,i*.085,0,.88,.055,.11,tile)
def misc(name):
    if name=='ceiling_module':box(0,0,0,2,.14,2,cream)
    if name=='floor_tile':box(0,-.05,0,1,.1,1,tile)
    if name=='wall_straight':box(0,1.55,0,2,3.1,.18,cream);box(0,.57,-.005,2,1.14,.20,green)
    if name=='wall_corner':box(0,1.55,0,2,3.1,.18,cream);box(.91,1.55,.91,.18,3.1,2,cream)
    if name=='concrete_column':box(0,1.65,0,.38,3.3,.38,cream);box(0,.5,0,.43,1,.43,green)
    if name=='keyboard':
        box(0,.017,0,.44,.034,.15,dark)
        for i in range(13):
            for j in range(4):box(-.185+i*.03,.038,-.048+j*.03,.022,.011,.019,iron)
    if name=='mouse':rod((0,.014,0),(0,.045,0),.046,iron,.032)
    if name=='computer':box(0,.23,0,.19,.46,.40,dark);box(0,.32,-.208,.14,.018,.014,iron)
    if name=='calendar':
        box(0,0,0,.32,.45,.02,white);box(0,.16,-.013,.32,.11,.012,red)
        for j in range(4):
            for i in range(7):box(-.12+i*.04,.05-j*.055,-.016,.021,.018,.008,iron)
    if name=='book_stack':
        for i in range(4):box(.011*i,.025+i*.043,0,.25,.044,.18,[red,blue,cream,green][i],i*5)
    if name=='mirror':box(0,0,0,.58,.76,.05,iron);box(0,0,-.029,.53,.70,.01,'#94acab')
    if name=='bin':rod((0,.02,0),(0,.42,0),.13,moss,.18);rod((0,.421,0),(0,.425,0),.15,dark)
    if name=='medicine_cabinet':
        box(0,.36,0,.64,.72,.21,cream);box(0,.36,-.122,.08,.27,.024,red);box(0,.36,-.122,.26,.09,.022,red)
    if name=='school_sign':box(0,0,0,1.0,.29,.05,green);box(-.46,0,-.031,.025,.22,.014,brass)
    if name=='microphone_stand':
        rod((0,.012,0),(0,.025,0),.11,iron);rod((0,.025,0),(0,.32,0),.014,iron)
        rod((0,.32,0),(0,.38,-.08),.035,dark,.043)
    if name=='phone':
        box(0,.037,0,.21,.074,.18,iron);box(0,.095,.028,.22,.045,.055,dark)
    if name=='cctv':
        box(0,0,0,.12,.13,.29,cream);box(0,0,-.15,.09,.08,.026,dark)
        rod((0,-.05,.08),(0,-.18,.20),.023,iron)
assets={'student_desk':desk,'student_chair':chair,'teachers_desk':lambda:table(1.55,.78),'teachers_chair':chair,'blackboard':classroom_board,'filing_cabinet':drawers,'metal_locker':lambda:cupboard(.86,1.88,.54),'wooden_cupboard':lambda:cupboard(.95,1.8,.48,wood),'bookshelf':shelf,'storage_rack':storage_rack,'clock':clock,'noticeboard':board,'ceiling_fan':fan,'ceiling_lamp':lamp,'emergency_lamp':lambda:lamp(True),'desk_lamp':desk_lamp,'monitor':monitor,'breaker_panel':breaker,'generator':generator,'school_speaker':speaker,'audio_mixer':console,'wooden_door':lambda:door(wood),'metal_door':lambda:door(green),'school_window':window,'washbasin':sink,'toilet':toilet,'clinic_bed':bed,'privacy_curtain':curtain,'cardboard_box':crate,'school_gate':gate,'flagpole':flag,'canteen_bench':bench,'food_counter':counter,'tropical_tree':lambda:planter(True),'potted_plant':planter,'trophy':stage_trophy,'picture_frame':bulletin_frame,'stage_podium':podium,'stage_curtain':stage_curtain,'staircase':stair,'balcony_railing':railing,'wall_door':doorwall,'wall_window':wallwindow,'roof_module':roof,'ventilation_module':vent}
for k,build in assets.items(): build();save(k)
for k in 'wall_straight wall_corner ceiling_module floor_tile concrete_column keyboard mouse computer calendar book_stack mirror bin medicine_cabinet school_sign microphone_stand phone cctv'.split():misc(k);save(k)
