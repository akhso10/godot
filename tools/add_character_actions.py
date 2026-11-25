"""Append authored skeletal actions to existing Blender GLBs without re-exporting meshes.

Run after build_characters.py. Existing animation names, skins, vertex data,
indices and bind-pose matrices remain untouched. Requires NumPy and SciPy.
Rotation offsets below use the model's upright rest axes (degrees).
"""
from pathlib import Path
import json
import struct
import numpy as np
from scipy.spatial.transform import Rotation

MODEL_DIR = Path(__file__).resolve().parents[1] / "assets/models/characters"
# Each target pose is defined on the bones it moves. Other bones use the bind
# pose. RootHeight displaces only the visual rig; gameplay controls locomotion.
REST = {}
SCAN = {"Head": (-4, 32, -4), "Chest": (3, 8, 0)}
FLINCH = {"Head": (-13, -16, 6), "Chest": (-11, 6, -5),
          "ArmL": (-66, -14, 12), "ForearmL": (-78, 0, -18),
          "ArmR": (-50, 12, -9), "ForearmR": (-61, 0, 16)}
LISTEN = {"Head": (2, 21, -12), "Chest": (5, 11, 0),
          "ArmR": (-25, 0, -14), "ForearmR": (-65, 0, 6)}
CUFF = {"Head": (12, 24, 1), "Chest": (5, -6, 0),
        "ArmL": (-39, -3, 6), "ForearmL": (-76, -12, -18),
        "ArmR": (-36, 8, -4), "ForearmR": (-80, 5, 26)}
POINT = {"Head": (0, 23, 0), "ArmR": (-85, 0, -20),
         "ForearmR": (-3, -10, 0), "Chest": (3, 13, 0)}
TALK = {"Head": (6, -7, 3), "Chest": (0, 7, -2),
        "ArmL": (-18, -4, 14), "ForearmL": (-61, -15, -6)}
HIDE = {"RootHeight": -.29, "ThighL": (-53, -5, 0), "ThighR": (-53, 6, 0),
        "CalfL": (98, 0, 0), "CalfR": (98, 0, 0), "Chest": (27, 0, 0),
        "Head": (-11, -8, -3), "ForearmL": (-82, 0, 0), "ForearmR": (-85, 0, 0)}
SIT = {"RootHeight": -.36, "ThighL": (-84, -4, 0), "ThighR": (-81, 7, 0),
       "CalfL": (84, 0, 0), "CalfR": (81, 0, 0), "ArmL": (-26, 0, -3),
       "ArmR": (-31, 0, 3), "ForearmL": (-55, 0, -4), "ForearmR": (-56, 0, 5),
       "Head": (8, 0, 0), "Chest": (9, 0, 0)}
REACH = {"RootHeight": -.12, "Chest": (39, -10, -6), "Head": (14, 8, 2),
         "ThighR": (-30, 0, 0), "CalfR": (52, 0, 0), "ThighL": (-36, 0, 0),
         "CalfL": (58, 0, 0), "ArmR": (-35, 7, -5), "ForearmR": (-14, 0, 0)}
PUSH = {"Chest": (10, -13, 0), "Head": (-6, 10, -2),
        "ArmR": (-69, 0, -8), "ForearmR": (-13, 0, 0), "ArmL": (-20, 8, 0)}
HOLD = {"Head": (18, 1, 0), "Chest": (4, 0, -1), "ArmL": (-47, -3, 5),
        "ArmR": (-44, 4, -2), "ForearmL": (-48, 0, -12), "ForearmR": (-53, 0, 13)}
LAMP = {"Head": (1, -13, -2), "ArmR": (-52, -5, -3),
        "ForearmR": (-34, 0, 0), "Chest": (3, -9, 0)}
RADIO = {"Head": (4, 9, 7), "ArmR": (-44, -14, -8), "ForearmR": (-112, 0, 21)}
HOVER = {"RootHeight": .07, "Head": (4, -6, 3), "Chest": (-3, -3, -2),
         "ArmL": (-5, 0, 7), "ArmR": (6, 0, -8), "ForearmL": (-6, 0, -3)}
LUNGE = {"RootHeight": -.07, "Chest": (22, -11, -4), "Head": (-16, 9, 4),
         "ArmL": (-109, 16, 7), "ArmR": (-79, -18, -5),
         "ForearmL": (-25, 0, -11), "ForearmR": (-57, 0, 9),
         "ThighL": (-23, 0, 0), "CalfL": (33, 0, 0)}


def stride(amount, arms, lift=0, lean=0):
    """Opposite contacts / passing pose of an in-place stride."""
    result = []
    for sign in (1, 0, -1, 0, 1):
        pose = {"Chest": (lean, -5*sign, 1.5*sign), "RootHeight": lift + .012*abs(sign)}
        for side, swing in (("L", sign), ("R", -sign)):
            pose["Thigh"+side] = (-amount*swing, 0, 0)
            pose["Calf"+side] = (max(0, amount*swing*.67), 0, 0)
            pose["Arm"+side] = (arms*swing-6, 0, 0)
            pose["Forearm"+side] = (-12 - arms*.5*(1-swing), 0, 0)
        result.append(pose)
    return result


def loop(name, seconds, a, b, c=None):
    return name, seconds, [a, b, c if c is not None else a, a]


def gesture(name, seconds, pose, accent=None):
    return name, seconds, [REST, pose, accent if accent is not None else pose, REST]


def make_clips(actor):
    if actor == "laras":
        return [loop("GhostIdle", 3.7, {"Head": (1,0,0)}, HOVER),
                ("SlowWalk", 2.25, stride(14, 4, .035, -3)),
                ("Appear", 1.8, [{"RootHeight": -.22, "Head": (34,0,0)}, {"Head": (20,0,0)}, HOVER]),
                ("Disappear", 1.75, [HOVER, {"Head": (18, -24, 0)}, {"RootHeight": -.26, "Head": (42,-37,0)}]),
                gesture("HeadTurn", 2.5, {"Head": (-5, -49, -7), "Chest": (0,-10,0)}),
                loop("Float", 3.1, HOVER, {**HOVER, "RootHeight": .19, "Head": (-3,10,-1)}),
                gesture("Reflection", 2.9, {"Head": (-8,21,-11), "ArmL": (-75,0,12), "ForearmL": (-20, 0,-5)})]
    if actor == "shadow_guardian":
        return [("Patrol", 1.45, stride(21, 13, 0, 9)),
                gesture("HeadTurn", 1.65, {"Head": (5,44,-2), "Chest": (8,3,0)}),
                loop("Listen", 1.8, {"Chest": (9,0,-1)}, LISTEN),
                ("Investigate", 1.20, stride(29, 8, -.015, 15)),
                ("Chase", .62, stride(52, 46, -.018, 20)),
                gesture("PushDoor", 1.1, PUSH),
                ("Attack", .53, [LISTEN, {"Chest": (-12,-17,3)}, LUNGE, {**LUNGE, "Head": (-4,11,-9)}]),
                ("Jumpscare", .72, [REST, LUNGE, {**LUNGE, "Head": (-23,-18,16)}, FLINCH]),
                ("ReturnPatrol", 1.32, stride(24, 16, 0, 7))]
    if actor == "raka":
        crouch_walk = []
        for step in stride(15, 11):
            p = dict(HIDE)
            for joint in ("ThighL", "ThighR", "CalfL", "CalfR", "ArmL", "ArmR"):
                p[joint] = (p.get(joint,(0,0,0))[0]+step[joint][0],0,0)
            crouch_walk.append(p)
        return [loop("CrouchIdle", 2.75, HIDE, {**HIDE, "Head":(-13,8,-2)}),
                ("CrouchWalk", 1.28, crouch_walk),
                gesture("Pickup", 1.18, REACH), gesture("Inspect", 2.9, HOLD),
                gesture("PushDoor", 1.25, PUSH), gesture("Flashlight", 2.4, LAMP),
                gesture("ChangeBattery", 2.05, CUFF, HOLD),
                gesture("Radio", 2.16, RADIO),
                ("Hide", 1.10, [REST, REACH, HIDE]),
                ("LeaveCover", 1.21, [HIDE, LISTEN, REST]),
                ("Fall", .79, [REST, FLINCH, {**HIDE, "Chest": (46,7,8)}]),
                gesture("Capture", .86, FLINCH)]
    return [loop("Talk", 1.78, REST, TALK, {**TALK, "Head":(-3,11,-3)}),
            loop("NervousIdle", 3.72, LISTEN, CUFF, SCAN),
            gesture("Fear", .98, FLINCH),
            ("Sit", 1.07, [REST, REACH, SIT]),
            ("StandUp", 1.24, [SIT, {**REACH, "Chest": (31,0,0)}, REST]),
            gesture("Point", 2.16, POINT),
            loop("Hide", 2.5, HIDE, {**HIDE, "Head":(-6,17,-5)}),
            ("Follow", 1.05, stride(28, 19, .0, 2)),
            ("Escape", .69, stride(43, 38, -.012, 13))]


def append_missing(path):
    source = path.read_bytes()
    size = struct.unpack_from("<I", source, 12)[0]
    doc = json.loads(source[20:20+size])
    blob = bytearray(source[28+size:28+size+doc["buffers"][0]["byteLength"]])
    names = {a["name"] for a in doc["animations"]}
    nodes = {doc["nodes"][j]["name"]: j for j in doc["skins"][0]["joints"]}
    parents = {child: j for j,node in enumerate(doc["nodes"]) for child in node.get("children", [])}
    identity = Rotation.identity()

    def bind(i):
        return Rotation.from_quat(doc["nodes"][i].get("rotation", [0,0,0,1]))

    def world_bind(i):
        return world_bind(parents[i]) * bind(i) if i in parents else bind(i)

    def accessor(values, kind):
        data = np.asarray(values,dtype="<f4")
        blob.extend(bytes((-len(blob)) % 4))
        doc["bufferViews"].append({"buffer":0,"byteOffset":len(blob),"byteLength":data.nbytes})
        blob.extend(data.tobytes())
        item = {"bufferView":len(doc["bufferViews"])-1,"componentType":5126,"count":len(data),"type":kind}
        if kind=="SCALAR":
            item.update(min=[float(data.min())],max=[float(data.max())])
        doc["accessors"].append(item)
        return len(doc["accessors"])-1

    for name, duration, poses in make_clips(path.stem.removesuffix("_character")):
        if name in names:
            continue
        times = accessor(np.linspace(0., duration, len(poses)), "SCALAR")
        anim = {"name":name, "samplers":[], "channels":[]}

        def channel(joint, target, data, kind):
            index = len(anim["samplers"])
            anim["samplers"].append({"input":times,"output":accessor(data,kind),"interpolation":"LINEAR"})
            anim["channels"].append({"sampler":index,"target":{"node":joint,"path":target}})

        for joint in sorted(set().union(*poses)):
            if joint=="RootHeight":
                j = nodes["Root"]
                rest = np.array(doc["nodes"][j].get("translation",[0,0,0]))
                channel(j,"translation",[rest+[0,p.get(joint,0),0] for p in poses],"VEC3")
                continue
            j = nodes[joint]
            basis = world_bind(parents[j]) if j in parents else identity
            keys = []
            for pose in poses:
                rotation = Rotation.from_euler("xyz",pose.get(joint,(0,0,0)),degrees=True)
                q = (basis.inv() * rotation * basis * bind(j)).as_quat()
                if keys and np.dot(keys[-1],q)<0:
                    q = -q
                keys.append(q)
            channel(j,"rotation",keys,"VEC4")
        doc["animations"].append(anim)
    if len(names)==len(doc["animations"]):
        return
    doc["buffers"][0]["byteLength"] = len(blob)
    raw = json.dumps(doc,ensure_ascii=False,separators=(",",":")).encode()
    raw += b" " * (-len(raw)%4)
    blob.extend(bytes((-len(blob)) % 4))
    path.write_bytes(struct.pack("<4sIIII",b"glTF",2,28+len(raw)+len(blob),len(raw),0x4e4f534a)+
                     raw+struct.pack("<II",len(blob),0x004e4942)+blob)
    print(path.name, len(doc["animations"]), "clips")


if __name__=="__main__":
    for file in sorted(MODEL_DIR.glob("*_character.glb")):
        append_missing(file)
