#!/usr/bin/env python3
"""Create a reproducible asset delivery manifest. Requires Python 3.10+ and Pillow."""
import argparse
import csv
import hashlib
import io
import json
import re
import struct
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ["asset_id", "asset_name", "category", "file_path", "file_format", "resolution",
          "file_size", "source", "license", "generation_prompt", "used_in_scene", "status",
          "usage", "sha256"]
PROJECT_ART = "Karya proyek; lihat docs/ASSET_LICENSES.md"
REF = re.compile(r'res://([\w./-]+\.(?:glb|png|webp|svg|ogg|ttf|tres|tscn|gd))(?=["\'])')
SUFFIXES = {".png", ".webp", ".jpg", ".svg", ".ogg", ".wav", ".ttf", ".glb", ".tres"}


def refs(path):
    return set(REF.findall(path.read_text(encoding="utf-8")))


def describe(path, blob, warnings):
    ext = path.suffix
    if ext in {".png", ".webp", ".jpg"}:
        with Image.open(io.BytesIO(blob)) as im:
            im.load()
            expected = {".png": "PNG", ".jpg": "JPEG", ".webp": "WEBP"}[ext]
            if im.format != expected:
                raise ValueError(f"file extension does not match {im.format}")
            if path.parts[1:3] == ("items", "masters"):
                needed = 1024
            elif path.parts[1:3] == ("items", "icons"):
                needed = 256
            elif path.parts[1:3] == ("items", "small"):
                needed = 128
            else:
                needed = None
            if needed and (im.size != (needed, needed) or "A" not in im.getbands()):
                raise ValueError(f"expected transparent {needed} x {needed} item icon")
            if max(im.size) > 2048:
                warnings.append(f"Review texture dimensions {im.size}: {path}")
            return f"{im.width}x{im.height}"
    if ext == ".svg":
        root = ET.fromstring(blob)
        if not root.tag.endswith("svg"):
            raise ValueError("not an SVG image")
        return f'{root.get("width", "?")}x{root.get("height", "?")}'
    if ext == ".glb":
        magic, version, length, meta_len, chunk = struct.unpack_from("<4sIII4s", blob)
        if magic != b"glTF" or version != 2 or length != len(blob) or chunk != b"JSON":
            raise ValueError("invalid GLB header")
        scene = json.loads(blob[20:20 + meta_len])
        if not (scene.get("scenes") and scene.get("meshes")):
            raise ValueError("GLB missing scenes or meshes")
        if path.stem.endswith("_character") and not (scene.get("skins") and scene.get("animations")):
            raise ValueError("character missing rig or animations")
    if ext == ".ogg" and not (blob.startswith(b"OggS") and b"\x01vorbis" in blob[:100]):
        raise ValueError("invalid Ogg Vorbis header")
    if ext == ".ttf" and not blob.startswith((b"\x00\x01\x00\x00", b"OTTO")):
        raise ValueError("font header invalid")
    if ext == ".tres" and not blob.startswith(b"[gd_resource"):
        raise ValueError("missing Godot resource header")
    return ""


def provenance(path):
    group = path.parts[1]
    source = {
        "character_studies": "Blender; tools/render_turnarounds.py",
        "audio": "Sintesis orisinal; tools/synthesize_audio.py",
        "art": "Ilustrasi digital proyek; ImageGen",
        "models": "Blender; tools/build_characters.py" if path.parts[2] == "characters"
                  else "Blender; tools/build_school_models.py",
        "items": "Blender; tools/model_items.py" if path.suffix != ".tres" else "tools/catalog_items.py",
        "materials": "Pembangkitan permukaan periodik; tools/materials.py",
        "ui": "Gambar vektor dan raster orisinal; tools/ui_icons.py",
        "vfx": "Tekstur efek orisinal; tools/render_vfx.py",
    }.get(group, "Berkas proyek")
    if group == "art" and any(p in path.parts for p in ("locations_3d", "captures")):
        source = "Tangkapan level Godot; proyek SMA Nusa Bangsa"
    brief = {"character_studies":"4 dan 20", "art":"4, 7, 12 dan 19", "models":"4, 8 dan 10",
             "items":"9 dan 15", "audio":"22", "materials":"11", "ui":"12 dan 13",
             "vfx":"21"}.get(group)
    if path.suffix == ".ttf":
        if "OpenSans" in path.name:
            return "Google; distribusi Debian fonts-open-sans", "Apache-2.0", ""
        return "DejaVu; distribusi Debian fonts-dejavu-core", "Bitstream Vera dan perubahan DejaVu", ""
    return source, PROJECT_ART, f"Brief: docs/MASTER_PROMPT.md § {brief}" if brief else ""


class Usage:
    """Classify known static references and the game's data-driven path builders."""
    def __init__(self, paths, errors):
        self.scripts = {p.stem:p.read_text() for p in (ROOT / "scripts").glob("*.gd")}
        self.campaign = (ROOT / "data/campaign.gd").read_text()
        self.direct = defaultdict(set)
        for file in [ROOT / "project.godot", *(ROOT/"scripts").glob("*.gd"),
                     *(ROOT/"scenes").rglob("*.tscn"), *(ROOT/"data").rglob("*.gd"),
                     *(ROOT/"assets").rglob("*.tres")]:
            for reference in refs(file):
                if not (ROOT / reference).is_file():
                    errors.append(f"Broken reference in {file.relative_to(ROOT)}: {reference}")
                self.direct[reference].add(file.relative_to(ROOT).as_posix())
        story = self.scripts["story"]
        self.drops = set(re.findall(r'"item"\s*:\s*"([\w-]+)"', self.campaign + story))
        self.inventory = self.drops | {"smartphone_raka"}
        self.world = self.scripts["world"]
        self.world_setup = self.world[self.world.index("func _school()"):]
        self.materials = {p.stem for p in paths if p.parts[1] == "materials" and p.suffix == ".tres"
                          and f'"{p.stem}"' in self.world_setup}
        self.mix = self.scripts["sound"].partition("const MIX")[2].partition("const CHAPTER_MODE")[0]
        self.sound_ids = set(re.findall(r'(?:sound\.play|_effect|_guard_effect)\("([\w-]+)"',
                                        "\n".join(self.scripts.values())))
        self.sound_ids.update(re.findall(r'"effect"\s*:\s*"([\w-]+)"',self.campaign))
        aliases = self.scripts["sound"].partition("const FOLEY")[2].partition("const BUS_GAIN")[0]
        alias_map = dict(re.findall(r'"([\w-]+)"\s*:\s*"([\w-]+)"',aliases))
        self.sound_files = {alias_map.get(i,i) for i in self.sound_ids}
        self.sound_files.update(alias_map.get(i,i) for i in ("click","pickup","catch"))
        self.ui_code = "\n".join(self.scripts.get(k, "") for k in ("main","interface","notebook","gallery"))
        for key in self.inventory:
            for folder, ext in (("catalog","tres"),("icons","png"),("models","glb")):
                rel = f"assets/items/{folder}/{key}.{ext}"
                if not (ROOT/rel).is_file():
                    errors.append(f"Missing inventory resource: {rel}")

    def role(self,path):
        key = path.stem
        subset = path.parts[1]
        direct = sorted(p for p in self.direct[path.as_posix()]
                        if p.startswith(("scripts/","scenes/","project.godot")))
        if direct:
            return "Runtime", " | ".join(direct)
        if subset == "items":
            folder = path.parent.name
            if folder == "masters":
                return "Master produksi", ""
            if folder == "small":
                return "Varian resolusi", ""
            if key in self.inventory and folder in ("icons","catalog"):
                return "Runtime", "scripts/notebook.gd"
            if key in self.drops and folder == "models":
                return "Runtime", "scripts/station.gd"
            return "Runtime", "scripts/gallery.gd; assets/items/catalog/" + key + ".tres"
        if subset == "materials":
            mat = key if path.suffix == ".tres" else path.parent.name
            if mat in self.materials:
                return "Runtime", "scripts/world.gd"
            return "Runtime", f"scripts/gallery.gd; assets/materials/{mat}.tres"
        if subset == "models" and path.parts[2] == "environment":
            if f'"{key}"' in self.world_setup:
                return "Runtime", "scripts/world.gd"
            return "Runtime", "scripts/gallery.gd"
        if subset == "art":
            if key in {"ending_good","ending_neutral","ending_bad"} and "ending_" in self.ui_code:
                return "Runtime", "scripts/main.gd"
            if key.endswith("_portrait") and key.removesuffix("_portrait") in re.findall(
                    r'\["(\w+)",\s*"',self.scripts["notebook"].partition("const SECTIONS")[0]):
                return "Runtime", "scripts/notebook.gd"
            if f'"{key}"' in self.ui_code:
                return "Runtime", "Antarmuka / galeri"
            return "Runtime", "scripts/gallery.gd"
        if subset == "character_studies":
            return "Runtime", "scripts/gallery.gd"
        if subset == "audio":
            if path.parent.name == "footsteps":
                return "Runtime", "scripts/player.gd"
            if f'"{key}"' in self.mix or key in self.sound_files:
                return "Runtime", "scripts/sound.gd; player atau actors"
            return "Runtime", "scripts/gallery.gd"
        if subset == "ui" and key.startswith("icon_"):
            id_ = key.removeprefix("icon_")
            if re.search(r'\btrue,\s*"' + re.escape(id_) + r'"', self.ui_code) or id_ in {"map","inventory","journal"}:
                return "Runtime", "Antarmuka / buku lapangan"
            return "Runtime", "scripts/gallery.gd"
        if subset == "vfx" and f'"{key}"' in self.scripts.get("atmosphere", ""):
            return "Runtime", "scripts/atmosphere.gd"
        return "Pustaka proyek", ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write ASSET_MANIFEST.csv; default checks drift")
    args = parser.parse_args()
    paths = sorted(p.relative_to(ROOT) for p in (ROOT/"assets").rglob("*")
                   if p.is_file() and p.suffix.lower() in SUFFIXES)
    errors, warnings = [], []
    use = Usage(paths, errors)
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    counts = Counter()
    names = Counter()
    unique = set()
    for path in paths:
        try:
            blob = (ROOT/path).read_bytes()
            if not blob:
                raise ValueError("empty file")
            resolution = describe(path, blob, warnings)
        except (OSError, ValueError, struct.error, ET.ParseError) as err:
            errors.append(f"{path}: {err}")
            continue
        asset_id = path.with_suffix("").as_posix().removeprefix("assets/")
        norm = asset_id.casefold()
        if norm in unique:
            errors.append(f"Duplicate asset ID ignoring case: {asset_id}")
        unique.add(norm)
        names[path.name] += 1
        role, reference = use.role(path)
        counts[role] += 1
        source, license_, brief = provenance(path)
        status = "Integrated" if role=="Runtime" else "Reviewed"
        writer.writerow(dict(zip(FIELDS, [asset_id,path.stem,"/".join(path.parts[1:-1]),
            path.as_posix(),path.suffix[1:],resolution,len(blob),source,license_,brief,
            reference,status,role,hashlib.sha256(blob).hexdigest()])))
    for warning in sorted(set(warnings)):
        print(warning, file=sys.stderr)
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        return 1
    manifest = ROOT/"ASSET_MANIFEST.csv"
    result = output.getvalue().encode("utf-8")
    if args.write:
        manifest.write_bytes(result)
    elif not manifest.exists() or manifest.read_bytes() != result:
        print("Manifest differs from assets. Inspect changes then run with --write.", file=sys.stderr)
        return 1
    reused = sum(n>1 for n in names.values())
    print(f"{len(paths)} assets, {len(unique)} unique IDs, {reused} repeated basenames across directories.")
    print("; ".join(f"{k}: {v}" for k,v in sorted(counts.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
