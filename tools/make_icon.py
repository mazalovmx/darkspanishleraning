"""Draws the application icon (own art, CC0): a closed book with an ember flame,
for "El Índice de Ceniza". Writes game/icon.png (256 px) and game/icon.ico.
Run: python3 tools/make_icon.py"""
from PIL import Image, ImageDraw, ImageFilter

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# Dark rounded tile.
d.rounded_rectangle((6, 6, S - 6, S - 6), radius=36, fill=(29, 24, 21, 255), outline=(150, 112, 52, 255), width=6)
# Book: cover, spine, page edge, gold frame.
d.rounded_rectangle((52, 44, 204, 212), radius=10, fill=(96, 52, 34, 255), outline=(40, 20, 12, 255), width=4)
d.rectangle((52, 44, 76, 212), fill=(70, 36, 24, 255))
d.rectangle((196, 52, 206, 204), fill=(222, 206, 170, 255))
d.rectangle((88, 60, 188, 196), outline=(214, 172, 84, 255), width=4)
# Ash under the flame.
for x, y, r in [(112, 168, 14), (138, 170, 16), (126, 176, 12), (152, 174, 10)]:
    d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=(120, 116, 112, 255))
# Ember flame: glow, outer, inner.
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((86, 70, 182, 178), fill=(255, 140, 40, 120))
img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(14)))
d = ImageDraw.Draw(img)
d.polygon([(136, 74), (166, 122), (164, 150), (150, 166), (122, 166), (106, 148), (108, 120), (122, 104), (124, 128)], fill=(232, 96, 30, 255))
d.polygon([(136, 108), (152, 134), (148, 156), (134, 162), (120, 154), (120, 136), (130, 126)], fill=(255, 206, 92, 255))
img.save("game/icon.png")
img.save("game/icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("ok")
