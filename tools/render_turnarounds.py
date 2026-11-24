"""Render front, side and back model views for the character art references.
Run: blender -b -t 2 -P tools/render_turnarounds.py
"""
import bpy
from pathlib import Path
from mathutils import Vector

base=Path(__file__).resolve().parents[1]
output=base/"assets"/"character_studies"
output.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=10
scene.cycles.use_denoising=False
scene.render.resolution_x=310
scene.render.resolution_y=450
scene.render.resolution_percentage=100
scene.render.film_transparent=False
scene.world.use_nodes=True
scene.world.node_tree.nodes.get("Background").inputs[0].default_value=(.16,.18,.175,1)
scene.world.node_tree.nodes.get("Background").inputs[1].default_value=.65
scene.view_settings.view_transform="AgX"

def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()

for file in sorted((base/"assets/models/characters").glob("*_character.glb")):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=str(file))
    # Stand neutrally, independent of the initial pose of the first imported clip.
    for obj in bpy.context.scene.objects:
        if obj.type=="ARMATURE":
            obj.animation_data_clear()
            for bone in obj.pose.bones:
                bone.matrix_basis.identity()
    name=file.stem.removesuffix("_character")
    height=2 if name=="shadow_guardian" else 1.7
    bpy.ops.object.camera_add(location=(0,-4,height/2))
    cam=bpy.context.object
    scene.camera=cam
    cam.data.type="ORTHO"
    cam.data.ortho_scale=height*1.18
    for location,energy,size,color in (((-2.0,-2.6,3.5),165,2.2,(1,.92,.78)),((2,-1,2.8),90,1.5,(.78,.89,1)),((0,1.8,2.5),140,1.4,(1,.79,.62))):
        bpy.ops.object.light_add(type="AREA",location=location)
        lamp=bpy.context.object
        lamp.data.energy=energy
        lamp.data.shape="DISK"
        lamp.data.size=size
        lamp.data.color=color
        aim(lamp,(0,0,height*.58))
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,.016))
    m=bpy.data.materials.get("Kertas") or bpy.data.materials.new("Kertas")
    m.diffuse_color=(.11,.13,.12,1)
    m.use_nodes=True
    m.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.11,.13,.12,1)
    bpy.context.object.data.materials.append(m)
    for view, pos in (("front",(0,-4)),("side",(4,0)),("back",(0,4))):
        cam.location=(pos[0],pos[1],height*.55)
        aim(cam,(0,0,height*.505))
        scene.render.filepath=str(output/(name+"_"+view+".png"))
        bpy.ops.render.render(write_still=True)
