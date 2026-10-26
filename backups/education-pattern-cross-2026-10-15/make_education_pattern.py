"""Build the Education watermark tile from the ትምህርት icon (lectern with Ge'ez letters), the same
way the Mezmur tile was made: one tan colour, the drawing carried by the alpha channel, a seamless
192x192 tile with a large motif and a small, fainter half-drop motif.

usage: python -I edu_pattern.py <edu_icon.png> <mezmur_pattern.png> <out_dir>
"""
import sys
from PIL import Image, ImageChops, ImageFilter, ImageOps

icon_path, ref_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
TILE = 192

# The exact tan of the existing tiles (alpha-weighted mean of the Mezmur tile).
ref = Image.open(ref_path).convert('RGBA')
tot = [0.0, 0.0, 0.0]
wsum = 0.0
for r, g, b, a in ref.getdata():
    if a > 0:
        tot[0] += r * a; tot[1] += g * a; tot[2] += b * a; wsum += a
TAN = tuple(round(c / wsum) for c in tot)
print('tan', TAN, '#%02X%02X%02X' % TAN)

src = Image.open(icon_path).convert('RGBA')
bbox = src.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox()
src = src.crop(bbox)
W, H = src.size
mask = src.getchannel('A').point(lambda a: 255 if a > 40 else 0)
lum = ImageOps.grayscale(src.convert('RGB'))

# 1) the letters and the cross: light carving on the dark wood.
letters = lum.point(lambda v: 255 if v > 150 else 0)
letters = ImageChops.multiply(letters, mask.filter(ImageFilter.MinFilter(9)))
letters = letters.filter(ImageFilter.MaxFilter(3))

# 2) the furniture's lines: edges of the (smoothed) wood, without the wood grain.
smooth = lum.filter(ImageFilter.GaussianBlur(2.2))
edges = smooth.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 5 else 0)
edges = ImageChops.multiply(edges, mask.filter(ImageFilter.MinFilter(5)))
edges = edges.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(5))

# 3) the silhouette outline.
outline = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(9)), mask.filter(ImageFilter.MinFilter(3)))

art = ImageChops.lighter(ImageChops.lighter(outline, edges), letters)
art = art.filter(ImageFilter.GaussianBlur(0.8))


def motif(height: int, strength: float) -> Image.Image:
    w = round(W * height / H)
    a = art.resize((w, height), Image.LANCZOS).point(lambda v: min(255, int(v * strength)))
    m = Image.new('RGBA', (w, height), TAN + (0,))
    m.putalpha(a)
    return m


big = motif(124, 1.25)
small = motif(56, 0.55)

# Paint on a 3x3 canvas and keep the centre tile, so motifs crossing an edge wrap around seamlessly.
canvas = Image.new('RGBA', (TILE * 3, TILE * 3), TAN + (0,))
def place(m, cx, cy):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            x = TILE + cx + dx * TILE - m.width // 2
            y = TILE + cy + dy * TILE - m.height // 2
            canvas.alpha_composite(m, (x, y))
place(big, TILE // 2, TILE // 2 - 6)
place(small, 0, 0)  # the half-drop: tile corners
tile = canvas.crop((TILE, TILE, TILE * 2, TILE * 2))
tile.save(f'{out_dir}/education_pattern.png', optimize=True)

# 3x3 preview on the light canvas colour, like the other *_pattern_preview.png files.
prev = Image.new('RGBA', (TILE * 3, TILE * 3), (245, 242, 237, 255))
for i in range(3):
    for j in range(3):
        prev.alpha_composite(tile, (i * TILE, j * TILE))
prev.convert('RGB').save(f'{out_dir}/education_pattern_preview.png', optimize=True)
print('ok', tile.size)
