"""Prepare runtime icon sizes and resource records from the Blender renders."""
from pathlib import Path
from PIL import Image
from item_data import ITEMS
root=Path(__file__).resolve().parents[1]/'assets'/'items'
for id,name,desc,kind,meters in ITEMS:
 with Image.open(root/'masters'/(id+'.png')) as image:
  assert image.size==(1024,1024) and image.mode=='RGBA' and image.getbbox()
  for category,size in [('icons',256),('small',128)]:
   (root/category).mkdir(exist_ok=True)
   # Alpha-aware filtering preserves the edges of narrow keys and antennae.
   image.resize((size,size),Image.Resampling.LANCZOS).save(root/category/(id+'.png'),optimize=True)
 usable='true' if id in ('flashlight','battery','walkie_talkie','cassette_tape') else 'false'
 stackable='true' if id=='battery' else 'false'
 (root/'catalog'/(id+'.tres')).write_text(f'''[gd_resource type="Resource" script_class="SchoolItem" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/item_definition.gd" id="definition"]
[ext_resource type="Texture2D" path="res://assets/items/icons/{id}.png" id="icon"]
[ext_resource type="PackedScene" path="res://assets/items/models/{id}.glb" id="model"]

[resource]
script = ExtResource("definition")
item_id = &"{id}"
display_name = "{name}"
description = "{desc}"
icon = ExtResource("icon")
world_model = ExtResource("model")
item_type = &"{kind}"
stackable = {stackable}
max_stack = {9 if id=='battery' else 1}
quest_item = {'false' if kind in ('pribadi','persediaan') else 'true'}
usable = {usable}
''')
