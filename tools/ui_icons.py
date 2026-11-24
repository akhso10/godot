"""Render the school's original wayfinding symbols and application emblem."""
from pathlib import Path
from PIL import Image, ImageDraw
from xml.sax.saxutils import escape

ui = Path(__file__).resolve().parents[1] / "assets/ui"
(ui / "icons").mkdir(exist_ok=True)
paths = {
    "play":"M6 4 L20 12 6 20 Z","continue":"M4 4 V11 H11 M4 11 A8 8 0 1 1 5 18",
    "exit":"M10 3 H4 V21 H10 M9 12 H22 M16 6 L22 12 16 18",
    "settings":"M3 6 H7 M12 6 H21 M3 17 H13 M18 17 H21 M7 3 H12 V9 H7 Z M13 14 H18 V20 H13 Z",
    "back":"M12 4 L4 12 12 20 M4 12 H22", "inventory":"M5 20 V8 L8 5 H16 L19 8 V20 Z M9 5 V3 H15 V5 M8 14 H16 V18 H8 Z",
    "journal":"M4 4 H13 Q17 3 20 5 V21 Q17 19 13 20 H4 Z M8 4 V20 M11 9 H16 M11 13 H16",
    "map":"M2 5 L8 3 16 6 22 3 V19 L16 22 8 19 2 21 Z M8 3 V19 M16 6 V22",
    "mission":"M5 21 V3 L19 4 15 8 19 12 5 11",
    "key":"M11 8 A4 4 0 1 0 3 8 A4 4 0 0 0 11 8 M10 10 L20 20 22 18 M16 16 L18 14",
    "flashlight":"M5 3 H19 L17 9 15 11 V21 H9 V11 L7 9 Z M8 8 H16 M12 13 V15",
    "battery":"M3 6 H19 V9 H22 V15 H19 V18 H3 Z M6 9 V15 M10 9 V15",
    "stamina":"M13 2 L4 14 H11 L10 22 20 9 H13 Z",
    "health":"M3 7 H9 V2 H15 V7 H21 V14 H15 V21 H9 V14 H3 Z",
    "document":"M5 2 H15 L20 7 V22 H5 Z M15 2 V8 H20 M9 12 H16 M9 16 H15",
    "evidence":"M2 5 H22 V20 H2 Z M4 17 L9 12 12 15 15 10 21 17 M6 9 H7",
    "radio":"M7 9 V2 M5 9 H18 V22 H5 Z M8 12 H15 M8 15 H15 M8 18 H11",
    "interact":"M8 13 V5 Q9 2 11 5 V11 M11 9 Q14 7 15 10 Q18 8 19 12 Q22 12 21 16 L18 21 H10 L3 14 Q4 11 8 14",
    "locked":"M5 11 H19 V21 H5 Z M8 11 V7 A4 4 0 0 1 16 7 V11 M12 14 V17",
    "unlocked":"M5 11 H19 V21 H5 Z M8 11 V7 A4 4 0 0 1 16 7 M12 14 V17",
    "eye":"M2 12 Q12 -2 22 12 Q12 26 2 12 Z M15 12 A3 3 0 1 1 9 12 A3 3 0 0 1 15 12",
    "hidden":"M3 11 Q9 3 15 6 M20 9 L22 12 Q13 24 4 15 M3 21 L21 3",
    "sound":"M2 9 H7 L13 4 V20 L7 15 H2 Z M16 8 Q21 12 16 16 M19 5 Q26 12 19 19",
    "music":"M9 17 V6 L20 3 V15 M9 17 A3 3 0 1 1 7 15 M20 15 A3 3 0 1 1 18 13",
    "mouse":"M5 13 V10 A7 7 0 0 1 19 10 V14 A7 7 0 0 1 5 14 Z M12 4 V10",
    "keyboard":"M2 5 H22 V19 H2 Z M5 9 H6 M9 9 H10 M13 9 H14 M17 9 H18 M6 15 H18",
    "save":"M4 3 H17 L21 7 V21 H4 Z M8 3 V10 H16 V3 M8 21 V14 H17 V21",
    "load":"M2 19 V5 H9 L11 7 H20 V10 M3 19 L6 11 H23 L19 20 H3 Z",
    "warning":"M12 2 L23 21 H1 Z M12 9 V14 M12 17 V18","check":"M3 12 L9 18 21 5",
    "close":"M4 4 L20 20 M20 4 L4 20"
}
for name, path in paths.items():
    (ui/"icons"/f"icon_{name}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24"><path d="{escape(path)}" stroke="#e8e6df" fill="none" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>')
(ui/"crest.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="70" viewBox="0 0 64 70"><g fill="none" stroke="#e7e3d0" stroke-width="2"><path d="M5 5 Q32 1 59 5 V36 Q57 53 32 66 Q7 53 5 36 Z M10 10 Q32 6 54 10 V36 Q52 49 32 60 Q12 49 10 36 Z"/><path d="M16 30 Q24 27 32 34 Q40 27 48 30 V42 Q39 40 32 46 Q24 40 16 42 Z M32 34 V46 M32 17 V28 M26 24 L32 16 38 24"/></g></svg>')
im=Image.new("RGB",(1024,1024),"#13201d")
d=ImageDraw.Draw(im)
for y in range(1024):
    d.line((0,y,1024,y),fill=(16+y//72,27+y//82,23+y//98))
d.polygon([(0,670),(370,386),(690,447),(1024,292),(1024,1024),(0,1024)],fill="#0a120f")
d.polygon([(90,662),(420,459),(911,467),(911,512),(420,504),(90,707)],fill="#727668")
for x in range(230,900,110):
    d.rectangle((x,612,x+69,729),fill="#384640" if x!=670 else "#e5b06c")
    d.line((x+34,612,x+34,729),fill="#131d17",width=7)
d.rectangle((110,800,925,817), fill="#5a6255")
d.ellipse((400,237,615,455),fill="#aa8c60")
d.polygon([(387,431),(405,375),(609,375),(632,431)], fill="#aa8c60")
d.rectangle((380,433,640,454),fill="#d0bd94")
d.ellipse((485,451,535,485),fill="#a98863")
im.save(ui/"app_icon.png")
