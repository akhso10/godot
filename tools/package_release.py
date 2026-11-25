"""Package a committed source tree and an exported Windows build. Python 3."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(exist_ok=True, parents=True)
prefix = "sekolah-setelah-tengah-malam"
paths = subprocess.check_output(["git","ls-files","-z"],cwd=root).decode().strip("\0").split("\0")
licenses = ["docs/ASSET_LICENSES.md", "docs/licenses/GODOT-NOTICES.txt"] + [x for x in paths if x.startswith("assets/ui/fonts/") and x.endswith(".txt")]
kinds = {
    "source": [(n,n) for n in paths],
    "assets": [(n,n) for n in paths if n.startswith("assets/") or n in licenses or n in ("ASSET_MANIFEST.csv","scripts/item_definition.gd")],
    "windows": [("build/Sekolah.exe","Sekolah.exe"),("build/Sekolah.pck","Sekolah.pck")] + [(x,"licenses/"+Path(x).name) for x in licenses]
}
sums = []
for kind, entries in kinds.items():
    archive = args.output/f"{prefix}-{kind}.zip"
    with zipfile.ZipFile(archive,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as package:
        # Godot Project Manager makes folders only when it reads a directory
        # entry. Write every parent before its children, including hidden paths.
        folders = {folder for _, target in entries for folder in PurePosixPath(target).parents
                   if folder != PurePosixPath(".")}
        for folder in sorted(folders, key=lambda path: (len(path.parts), path.as_posix())):
            package.mkdir(folder.as_posix())
        for local, target in entries:
            package.write(root/local, target)
    with zipfile.ZipFile(archive) as package:
        created = {PurePosixPath(".")}
        for member in package.infolist():
            path = PurePosixPath(member.filename)
            if path.parent not in created:
                raise RuntimeError(f"{archive.name}: missing parent entry before {member.filename}")
            if member.is_dir():
                created.add(path)
        if package.testzip():
            raise RuntimeError(f"Invalid ZIP {archive}")
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream,"sha256").hexdigest()
        sums.append(f"{digest}  {archive.name}")
    print(f"{kind}: {len(entries)} files, {archive.stat().st_size:,} bytes")
(args.output/"SHA256SUMS.txt").write_text("\n".join(sums)+"\n")
