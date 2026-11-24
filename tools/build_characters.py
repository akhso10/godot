"""Regenerate the six character GLBs with Blender 4.3 in background mode.

blender -b -P tools/build_characters.py
All measurements use metres. The figures face Blender -Y (Godot +Z).
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1] / "assets/models/characters"
ROOT.mkdir(exist_ok=True, parents=True)
skin = (0.49, 0.275, 0.172)
chalk = (0.75, 0.74, 0.68)
trousers = (0.155, 0.17, 0.175)
black = (0.025, 0.022, 0.021)
shoe = (0.038, 0.039, 0.039)
objects = []
bones = []
materials = {}


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bones.clear()
    objects.clear()


def material(color):
    if color not in materials:
        m = bpy.data.materials.new("Pigment_" + "_".join(str(round(c * 100)) for c in color))
        m.use_nodes = True
        lin = tuple((v / 12.92 if v < .04045 else ((v + .055) / 1.055)**2.4) for v in color)
        m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*lin, 1)
        m.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = .78
        m.diffuse_color = (*lin, 1)
        materials[color] = m
    return materials[color]


def part(name, color, joint, smooth=False):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(color))
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    objects.append((obj, joint))
    return obj


def orb(name, xyz, size, color, joint):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=xyz)
    obj = part(name, color, joint, True)
    obj.scale = size
    return obj


def box(name, xyz, size, color, joint, tilt=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = part(name, color, joint)
    obj.dimensions = size
    obj.rotation_euler.y = tilt
    return obj


def rings(name, bands, color, joint, n=12):
    # Each ring has centre xyz and horizontal radii. Changing ring centre adds asymmetry.
    vertices = [(x + a * math.cos(i * math.tau / n), y + b * math.sin(i * math.tau / n), z)
                for x, y, z, a, b in bands for i in range(n)]
    faces = [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i)
             for j in range(len(bands)-1) for i in range(n)]
    faces.extend([tuple(reversed(range(n))), tuple(range(len(vertices)-n,len(vertices)))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return part(name,color,joint,True)


def line(name, a, b, radius, color, joint):
    start, end = Vector(a), Vector(b)
    vec = end-start
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=vec.length, location=(start+end)/2)
    obj = part(name, color, joint, True)
    obj.rotation_euler = vec.to_track_quat("Z", "Y").to_euler()
    return obj


def make_rig():
    arm = bpy.data.armatures.new("Anatomi")
    rig = bpy.data.objects.new("Karakter", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in bones:
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj, joint in objects:
        group = obj.vertex_groups.new(name=joint)
        group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
    # One skinned mesh, small material palette and one pose calculation per actor.
    bpy.ops.object.select_all(action="DESELECT")
    for obj,_ in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0][0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = "Seragam_dan_tubuh"
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    mesh.parent = rig
    mod = mesh.modifiers.new("Pose", "ARMATURE")
    mod.object = rig
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    return rig


def animate(rig):
    rig.animation_data_create()
    for name, angle, frames in (("Idle", 0, 72),("Walk", .51, 32),("Run", .82, 22),
                                ("Search", 0, 90),("Startle", 0, 24),("Signal", 0, 60)):
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        for step in range(5):
            phase = math.tau * step / 4
            for pb in rig.pose.bones:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (0,0,0)
            for s,side in ((1,"L"),(-1,"R")):
                wave = s*math.cos(phase)
                rig.pose.bones["Thigh"+side].rotation_euler.x = angle*wave
                rig.pose.bones["Calf"+side].rotation_euler.x = angle*max(0,-wave)*.78
                rig.pose.bones["Arm"+side].rotation_euler.x = -angle*wave*.82
                rig.pose.bones["Forearm"+side].rotation_euler.x = -angle*(.42 + .36*wave)
            rig.pose.bones["Chest"].rotation_euler.x = .02*math.cos(phase) + (.12 if name=="Run" else 0)
            rig.pose.bones["Head"].rotation_euler.y = (.55 if name=="Search" else .045)*math.sin(phase)
            if name in ("Signal","Startle"):
                rig.pose.bones["ArmL"].rotation_euler.x = -1.25*(1-math.cos(phase))/2
                rig.pose.bones["ForearmL"].rotation_euler.x = -.75*(1-math.cos(phase))/2
            for pb in rig.pose.bones:
                pb.keyframe_insert(data_path="rotation_euler", frame=1+round(frames*step/4))
        track=rig.animation_data.nla_tracks.new()
        track.name=name
        track.strips.new(name,1,action)
        rig.animation_data.action = None
    bpy.context.scene.frame_set(1)


def character(who):
    clear()
    girl = who=="laras"
    guard = who=="shadow_guardian"
    skin_color = (0.7, .64, .58) if girl else ((.06,.054,.045) if guard else skin)
    coat = {"raka":(.105,.15,.21),"akbar":(.31,.115,.14),"shadow_guardian":(.155,.17,.165)}.get(who,chalk)
    hair = (.059,.049,.045)
    bones.extend([("Root",(0,0,.82),(0,0,.98),None),("Chest",(0,0,.96),(0,0,1.41),"Root"),
                  ("Head",(0,0,1.41),(0,0,1.68),"Chest")])
    for s,side in ((1,"L"),(-1,"R")):
        a,b,c=s*.115,s*.217,s*.265
        bones.extend([("Thigh"+side,(a,0,.93),(a,.012,.50),"Root"),
                      ("Calf"+side,(a,.012,.50),(a,-.01,.092),"Thigh"+side),
                      ("Arm"+side,(b,0,1.38),(c,.02,1.11),"Chest"),
                      ("Forearm"+side,(c,.02,1.11),(s*.275,-.03,.85),"Arm"+side)])
        leg = skin_color if girl else trousers if not guard else (.105,.108,.096)
        rings("Pipa celana atas",[(a,0,.47,.070,.073),(a,.006,.57,.081,.077),
             (a,.005,.79,.103,.099),(a,0,.96,.099,.1)],leg,"Thigh"+side)
        rings("Lipat lutut",[(a,-.008,.10,.056,.065),(a,0,.145,.064,.07),
             (a,.016,.31,.076,.081),(a,.006,.48,.072,.074),(a,0,.51,.070,.067)],leg,"Calf"+side)
        orb("Sepatu pantofel",(a,-.044,.082),(.077,.136,.074),shoe,"Calf"+side)
        orb("Sol",(a,-.046,.046),(.082,.143,.03),(.095,.094,.086),"Calf"+side)
        for k in range(3):
            line("Tali",(a-.031,-.095+k*.019,.133),(a+.031,-.089+k*.019,.132),.003,trousers,"Calf"+side)
        rings("Lengan baju",[(c,.01,1.09,.07,.063),(s*.26,.009,1.18,.067,.068),
             (s*.223,.006,1.35,.084,.088),(s*.203,0,1.39,.061,.066)],coat,"Arm"+side)
        rings("Lengan bawah",[(s*.277,-.026,.87,.039,.044),(c,.006,1.015,.053,.053),
             (c,.014,1.105,.058,.055)],coat if who in ("raka","akbar") or guard else skin_color,"Forearm"+side)
        orb("Tangan",(s*.278,-.032,.839 if not guard else .803),(.043,.045,.078 if not guard else .12),skin_color,"Forearm"+side)
        orb("Jempol",(s*.248,-.057,.862),(.019,.025,.041),skin_color,"Forearm"+side)
    rings("Torso",[(0,.011,.9,.168,.122),(0,.005,.96,.18,.129),(0,.004,1.10,.177,.107),
         (0,0,1.29,.212,.122),(0,.009,1.36,.23,.115),(0,.002,1.41,.166,.085)],coat,"Chest")
    if girl or guard:
        rings("Rok" if girl else "Ekor mantel",[(0,.012,.559,.215,.16),(0,.01,.75,.199,.141),
              (0,0,.974,.162,.119)],trousers if girl else coat,"Root",18)
    rings("Sabuk",[(0,0,.932,.178,.128),(0,0,.963,.18,.127)],black,"Root")
    box("Gesper",(0,-.127,.947),(.045,.01,.03),(.42,.42,.39),"Root")
    # Flat lapels, clean tie and shirt patch break the silhouette in torch light.
    for s in (-1,1):
        line("Kerah",(s*.075,-.057,1.407),(s*.033,-.121,1.32),.014,chalk if not guard else coat,"Chest")
    if who in ("raka","akbar"):
        box("Kemeja",(0,-.109,1.171),(.101,.03,.395),chalk,"Chest")
    if not guard:
        box("Dasi",(0,-.128,1.255),(.027,.015,.196),trousers,"Chest")
        box("Saku",(-.115,-.108,1.255),(.056,.009,.06),coat,"Chest")
        box("Lencana sekolah",(-.115,-.115,1.267),(.024,.006,.027),(.55,.38,.21),"Chest")
        for z in (1.07,1.11,1.15):
            orb("Kancing",(0,-.119,z),(.005,.004,.005),(.8,.79,.72),"Chest")
    rings("Leher",[(0,.011,1.369,.055,.05),(0,.005,1.49,.055,.048)],skin_color,"Head")
    rings("Wajah",[(0,-.026,1.464,.043,.050),(0,-.013,1.486,.078,.078),
        (0,0,1.547,.105,.090),(0,.005,1.607,.106,.092),(0,.012,1.66,.084,.084),
        (0,.014,1.682,.049,.048)],skin_color,"Head",20)
    for s in (-1,1):
        orb("Telinga",(s*.104,.005,1.556),(.017,.019,.031),skin_color,"Head")
    if not guard:
        for s in (-1,1):
            orb("Putih mata",(s*.042,-.082,1.572),(.021,.008,.008),(.68,.62,.53),"Head")
            orb("Iris",(s*.042,-.090,1.572),(.008,.004,.008),black,"Head")
            line("Alis",(s*.021,-.088,1.594),(s*.068,-.072,1.591),.004,hair,"Head")
        orb("Hidung",(0,-.093,1.542),(.016,.023,.025),skin_color,"Head")
        line("Bibir",(-.022,-.088,1.51),(.022,-.088,1.51),.0035,(.29,.154,.129),"Head")
        orb("Rambut",(0,.022,1.635),(.11,.105,.069),hair,"Head")
        for i in range(9):
            x = -.08 + .02*i
            o = orb("Poni",(x,-.059 + abs(x)*.30,1.634+.009*math.sin(i)),(.025,.032,.035),hair,"Head")
            o.rotation_euler.y = .51 if who != "akbar" else math.sin(i)*.63
        for s in (-1,1):
            orb("Pelipis",(s*.091,.016,1.575 if not girl else 1.497),
                (.021,.071,.053 if not girl else .15),hair,"Head")
    else:
        orb("Kerudung",(0,.04,1.61),(.132,.132,.166),coat,"Head")
        orb("Topeng",(0,-.080,1.577),(.095,.023,.101),(.034,.035,.036),"Head")
        orb("Topi satpam",(0,-.032,1.675),(.155,.165,.037),(.096,.102,.102),"Head")
        for i in range(3):
            line("Kunci besi",(.142+i*.01,-.103,.965),(.146+i*.014,-.114,.900-i*.008),.004,(.56,.4,.23),"Root")
    if who=="reski":
        for s in (-1,1):
            x=s*.045
            for a,b in (((x-.031,-.096,1.555),(x+.031,-.096,1.555)),
                        ((x-.031,-.096,1.588),(x+.031,-.096,1.588)),
                        ((x-.031,-.096,1.555),(x-.031,-.096,1.588)),
                        ((x+.031,-.096,1.555),(x+.031,-.096,1.588))):
                line("Bingkai",a,b,.0035,black,"Head")
        line("Jembatan",(-.015,-.098,1.578),(.015,-.098,1.578),.003,black,"Head")
        box("Jam tangan",(.275,-.024,.916),(.084,.07,.032),black,"ForearmL")
    if who in ("akbar","reski","raka"):
        pack = {"akbar":(.29,.31,.31),"reski":(.27,.31,.19),"raka":(.095,.102,.112)}[who]
        orb("Ransel",(0,.125,1.17),(.159,.084,.199),pack,"Chest")
        box("Kantong ransel",(0,.202,1.138),(.2,.038,.125),pack,"Chest")
        for s in (-1,1):
            line("Tali tas",(s*.15,-.068,1.385),(s*.146,-.1,1.186),.015,pack,"Chest")
    elif girl:
        orb("Rambut belakang",(0,.080,1.51),(.098,.046,.158),hair,"Head")
        for s in (-1,1):
            orb("Pita",(s*.032,.126,1.565),(.041,.014,.022),chalk,"Head")
    rig=make_rig()
    animate(rig)
    if guard:
        rig.scale=(1.11,1.10,1.16)
    export(who+"_character")


def export(name):
    bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+".glb")),export_format="GLB",
        export_animations=True,export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
        export_yup=True,export_extras=False,export_cameras=False,export_lights=False)


def hand():
    clear()
    # Local axis +Y becomes Godot -Z. Torch and hand point away from the camera.
    orb("Gagang senter",(0,0,0),(.027,.111,.029),shoe,"")
    for y in (.045,.055,.065,.075):
        orb("Alur grip",(0,y,0),(.033,.005,.034),(.09,.10,.11),"")
    orb("Kepala senter",(0,.101,0),(.04,.038,.04),(.16,.17,.16),"")
    orb("Lensa",(0,.135,0),(.033,.004,.033),(.67,.68,.55),"")
    orb("Telapak",(.027,-.015,-.022),(.034,.054,.041),skin,"")
    for i in range(4):
        orb("Jari",(-.001,.024-i*.018,-.023),(.03,.010,.012),skin,"")
    orb("Ibu jari",(.023,.015,.016),(.018,.037,.012),skin,"")
    orb("Lengan",(.045,-.125,-.04),(.047,.096,.052),(.105,.15,.21),"")
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active=objects[0][0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    export("raka_first_person_hands")


for identity in ("reski","akbar","laras","shadow_guardian","raka"):
    character(identity)
hand()
