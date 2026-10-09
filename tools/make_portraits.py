"""Draws the portraits of the speakers added in 2026-10 (own art, CC0 like the rest of
the project's original content) in the chibi-bust manner of the Claw & Blade portraits.
Run: python3 tools/make_portraits.py  -> game/assets/portraits/<npc_id>.png"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "portraits")
INK = (34, 26, 22, 255)
SKIN = {"light": (232, 196, 160), "mid": (214, 168, 128), "olive": (190, 148, 104), "dark": (150, 104, 72)}

def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)

def bust(d, coat, trim=None, collar=None):
    d.ellipse((22, 104, 106, 124), fill=(92, 58, 34, 255), outline=INK, width=3)
    d.ellipse((26, 104, 102, 116), fill=(122, 80, 48, 255))
    d.rounded_rectangle((28, 72, 100, 112), radius=18, fill=coat + (255,), outline=INK, width=3)
    d.polygon([(64, 74), (52, 112), (76, 112)], fill=shade(coat, 0.8))
    if trim:
        d.line((64, 76, 64, 110), fill=trim + (255,), width=3)
    if collar:
        d.polygon([(50, 72), (64, 84), (78, 72)], fill=collar + (255,), outline=INK)

def head(d, skin):
    d.ellipse((76, 46, 88, 60), fill=shade(skin, 0.9), outline=INK, width=2)
    d.ellipse((36, 20, 88, 76), fill=skin + (255,), outline=INK, width=3)

def face(d, beard=None, moustache=None, glasses=False, eyes=(40, 32, 28)):
    for x in (50, 70):
        d.ellipse((x - 4, 44, x + 4, 52), fill=eyes + (255,))
        d.point((x - 1, 46), fill=(255, 255, 255, 255))
    d.line((62, 54, 60, 60), fill=INK, width=2)
    d.line((57, 66, 65, 65), fill=INK, width=2)
    if glasses:
        for x in (50, 70):
            d.ellipse((x - 8, 40, x + 8, 56), outline=(60, 60, 70, 255), width=2)
        d.line((58, 48, 62, 48), fill=(60, 60, 70, 255), width=2)
    if moustache:
        d.polygon([(52, 62), (60, 60), (68, 60), (74, 63), (64, 64)], fill=moustache + (255,), outline=INK)
    if beard:
        d.chord((40, 44, 84, 82), 20, 160, fill=beard + (255,), outline=INK, width=2)
        d.line((57, 66, 65, 65), fill=INK, width=2)

def hair(d, style, color):
    c = color + (255,)
    if style == "short":
        d.chord((36, 18, 88, 56), 180, 360, fill=c, outline=INK, width=3)
    elif style == "bald":
        d.arc((36, 20, 88, 76), 150, 210, fill=c, width=6)
        d.arc((36, 20, 88, 76), 330, 30, fill=c, width=6)
    elif style == "long":
        d.chord((34, 16, 90, 58), 180, 360, fill=c, outline=INK, width=3)
        d.rectangle((32, 36, 42, 82), fill=c, outline=INK, width=2)
        d.rectangle((82, 36, 92, 82), fill=c, outline=INK, width=2)
    elif style == "bun":
        d.ellipse((52, 6, 72, 26), fill=c, outline=INK, width=3)
        d.chord((36, 18, 88, 56), 180, 360, fill=c, outline=INK, width=3)
    elif style == "curly":
        for x, y in ((40, 26), (52, 18), (66, 18), (78, 26), (84, 38), (36, 38)):
            d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=c, outline=INK, width=2)

def headwear(d, kind, color):
    c = color + (255,)
    if kind == "hood":
        d.pieslice((28, 12, 96, 84), 180, 360, fill=c, outline=INK, width=3)
        d.rectangle((28, 46, 38, 86), fill=c, outline=INK, width=2)
        d.rectangle((86, 46, 96, 86), fill=c, outline=INK, width=2)
    elif kind == "scarf":
        d.chord((32, 14, 92, 60), 180, 360, fill=c, outline=INK, width=3)
        d.polygon([(34, 40), (90, 40), (86, 50), (38, 50)], fill=shade(color, 0.85), outline=INK)
    elif kind == "cap":
        d.chord((36, 16, 88, 54), 180, 360, fill=c, outline=INK, width=3)
        d.rectangle((30, 33, 70, 39), fill=shade(color, 0.8), outline=INK, width=2)
    elif kind == "straw":
        d.ellipse((22, 26, 102, 42), fill=c, outline=INK, width=3)
        d.chord((40, 10, 84, 44), 180, 360, fill=shade(color, 0.9), outline=INK, width=3)
    elif kind == "tall":
        d.ellipse((30, 28, 94, 40), fill=c, outline=INK, width=3)
        d.rectangle((44, 2, 80, 34), fill=c, outline=INK, width=3)
        d.rectangle((44, 26, 80, 31), fill=(150, 30, 30, 255))
    elif kind == "helmet":
        d.chord((34, 12, 90, 56), 180, 360, fill=c, outline=INK, width=3)
        d.rectangle((60, 4, 64, 16), fill=c, outline=INK)
        d.line((34, 34, 90, 34), fill=INK, width=3)
    elif kind == "bandana":
        d.chord((36, 18, 88, 54), 180, 360, fill=c, outline=INK, width=3)
        d.polygon([(84, 30), (98, 26), (96, 40)], fill=c, outline=INK)
    elif kind == "veil":
        d.pieslice((30, 14, 94, 90), 180, 360, fill=c, outline=INK, width=3)
        d.rectangle((30, 50, 40, 92), fill=c, outline=INK, width=2)
        d.rectangle((84, 50, 94, 92), fill=c, outline=INK, width=2)

def person(npc, skin, coat, hairstyle=None, hair_color=(60, 40, 30), wear=None, wear_color=None,
           beard=None, moustache=None, glasses=False, trim=None, collar=None, apron=None, scar=False):
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    bust(d, coat, trim, collar)
    if apron:
        d.rounded_rectangle((44, 84, 84, 112), radius=6, fill=apron + (255,), outline=INK, width=2)
    sk = SKIN[skin]
    if wear in ("hood", "veil"):
        headwear(d, wear, wear_color)
    head(d, sk)
    if hairstyle:
        hair(d, hairstyle, hair_color)
    face(d, beard, moustache, glasses)
    if wear and wear not in ("hood", "veil"):
        headwear(d, wear, wear_color)
    if wear in ("hood", "veil"):
        d.arc((28, 12, 96, 84), 200, 340, fill=INK, width=3)
    if scar:
        d.line((44, 40, 52, 56), fill=(150, 60, 60, 255), width=2)
    im.save(os.path.join(OUT, npc + ".png"))

def machine(npc, body, lens, antenna=False):
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((22, 104, 106, 124), fill=(92, 58, 34, 255), outline=INK, width=3)
    d.rounded_rectangle((30, 30, 98, 110), radius=10, fill=body + (255,), outline=INK, width=3)
    for y in (44, 92):
        for x in (38, 90):
            d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=shade(body, 0.6))
    d.ellipse((46, 46, 82, 82), fill=(30, 30, 36, 255), outline=INK, width=3)
    d.ellipse((54, 54, 74, 74), fill=lens + (255,))
    d.ellipse((58, 57, 64, 63), fill=(255, 255, 255, 200))
    d.rectangle((40, 92, 88, 100), fill=shade(body, 0.75), outline=INK, width=2)
    if antenna:
        d.line((64, 30, 64, 6), fill=INK, width=3)
        d.ellipse((58, 0, 70, 12), fill=lens + (255,), outline=INK, width=2)
        d.line((44, 30, 34, 12), fill=INK, width=3)
        d.line((84, 30, 94, 12), fill=INK, width=3)
    im.save(os.path.join(OUT, npc + ".png"))

os.makedirs(OUT, exist_ok=True)
person("fermin_cuesta", "light", (44, 58, 92), "short", (50, 36, 28), moustache=(50, 36, 28), trim=(200, 170, 80), collar=(230, 230, 220))
person("clara_ibarra", "mid", (96, 96, 104), "bun", (90, 56, 36), collar=(230, 230, 220))
person("nicolas_ferrer", "light", (56, 92, 64), "short", (110, 74, 44), glasses=True)
person("julian_pardo", "mid", (36, 34, 40), "short", (30, 28, 30), moustache=(30, 28, 30), collar=(230, 230, 220))
person("remedios_galan", "olive", (110, 70, 60), "curly", (180, 180, 180), wear="scarf", wear_color=(150, 60, 50))
person("marta_ugarte", "light", (120, 140, 170), "long", (140, 84, 40), apron=(235, 232, 220))
person("baltasar_quiroga", "mid", (140, 40, 40), "short", (60, 44, 30), beard=(60, 44, 30), trim=(210, 180, 90))
person("catalina_rius", "mid", (170, 120, 80), wear="scarf", wear_color=(240, 236, 226), apron=(240, 236, 226))
person("damian_soler", "olive", (120, 86, 50), "short", (60, 40, 24), beard=(60, 40, 24), wear="straw", wear_color=(220, 190, 110))
person("pilar_montoya", "olive", (70, 66, 60), wear="scarf", wear_color=(60, 80, 110))
person("agueda_llorente", "light", (90, 70, 110), wear="veil", wear_color=(236, 230, 214))
person("anselmo_vidal", "mid", (110, 40, 36), moustache=(40, 30, 24), wear="helmet", wear_color=(150, 154, 160), trim=(200, 170, 80))
person("hernando_ruiz", "light", (60, 50, 70), "bald", (120, 100, 80), glasses=True, collar=(230, 230, 220))
person("tobias_marin", "light", (60, 110, 90), "short", (150, 90, 40), wear="cap", wear_color=(90, 120, 60))
person("lorenzo_villar", "dark", (80, 90, 110), "short", (30, 26, 24), beard=(30, 26, 24), wear="cap", wear_color=(70, 70, 76))
person("gonzalo_ferran", "light", (40, 44, 70), "short", (120, 96, 60), moustache=(120, 96, 60), wear="tall", wear_color=(30, 30, 34), collar=(240, 240, 240))
person("hermano_cipriano", "light", (200, 196, 186), wear="hood", wear_color=(176, 170, 160), trim=(170, 140, 60))
person("nuno_barragan", "olive", (70, 60, 48), "short", (40, 30, 24), beard=(40, 30, 24), wear="bandana", wear_color=(150, 40, 40), scar=True)
machine("el_indice", (150, 120, 70), (200, 90, 40))
machine("torre_rele", (110, 120, 120), (90, 190, 210), antenna=True)
# Comic speakers (2026-10-08): Rabelais's characters (public domain) and four original madmen.
person("juez_bridoya", "light", (40, 30, 50), "bald", (200, 200, 200), beard=(220, 220, 220), glasses=True, collar=(230, 230, 220))
person("panurgo", "olive", (150, 60, 40), "curly", (60, 40, 20), moustache=(60, 40, 20), wear="cap", wear_color=(200, 160, 40))
person("fray_juan", "mid", (100, 70, 40), "bald", (90, 60, 30), beard=(90, 60, 30), wear="hood", wear_color=(100, 70, 40))
person("janotus_bragmardo", "light", (20, 20, 24), "short", (170, 170, 170), wear="tall", wear_color=(20, 20, 24), glasses=True)
person("picrocolo", "light", (150, 30, 40), "long", (120, 70, 30), moustache=(120, 70, 30), wear="helmet", wear_color=(190, 190, 200), trim=(220, 180, 60))
person("ulpiano_sellado", "light", (70, 70, 80), "short", (90, 90, 90), glasses=True, collar=(230, 230, 220), trim=(160, 40, 40))
person("tia_brigida", "dark", (40, 60, 40), "long", (210, 210, 210), wear="scarf", wear_color=(60, 40, 30), apron=(120, 100, 70))
person("tiburcio_ruedas", "light", (110, 50, 30), "curly", (230, 230, 230), glasses=True, apron=(80, 60, 40), scar=True)
person("mamerto_remolacha", "olive", (60, 80, 50), "short", (40, 30, 20), moustache=(40, 30, 20), wear="helmet", wear_color=(150, 150, 160))
print("ok", len(os.listdir(OUT)))
