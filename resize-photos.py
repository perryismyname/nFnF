#!/usr/bin/env python3
"""
NAS-T photo prep.

Put your full-resolution photos in  photos-original/
Run:  python3 resize-photos.py
Get:  photos/          <- web-sized, sharp, fast (what the page displays)
      photos-full/     <- full-res, lightly optimized (what opens on click)

Re-run any time you add new photos. Existing files are overwritten.
"""

from PIL import Image, ImageOps
import os, shutil

SRC       = "photos-original"
OUT_WEB   = "photos"
OUT_FULL  = "photos-full"

# Display sizes. 2x the on-screen box so it stays sharp on retina/high-DPI
# screens, but far from the 6x downscale that causes artifacting.
WEB_MAX   = 1400     # longest edge for the web version
FULL_MAX  = 2600     # longest edge for the click-to-view version
WEB_Q     = 88       # JPEG quality, web
FULL_Q    = 90       # JPEG quality, full view

os.makedirs(OUT_WEB, exist_ok=True)
os.makedirs(OUT_FULL, exist_ok=True)

if not os.path.isdir(SRC):
    os.makedirs(SRC, exist_ok=True)
    print(f"Created '{SRC}/'. Put your original photos there and run this again.")
    raise SystemExit

def fit(img, longest):
    w, h = img.size
    if max(w, h) <= longest:
        return img.copy()
    if w >= h:
        nw, nh = longest, round(h * longest / w)
    else:
        nh, nw = longest, round(w * longest / h)
    # LANCZOS = high-quality resampling. This is the step the browser
    # was doing badly on the fly.
    return img.resize((nw, nh), Image.LANCZOS)

count = 0
for name in sorted(os.listdir(SRC)):
    ext = os.path.splitext(name)[1].lower()
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        continue

    path = os.path.join(SRC, name)

    # Logo passes through untouched (transparency must be preserved)
    if name.lower().startswith("logo"):
        shutil.copy2(path, os.path.join(OUT_WEB, name))
        print(f"  logo  {name}  (copied as-is)")
        count += 1
        continue

    img = Image.open(path)
    img = ImageOps.exif_transpose(img)      # honor camera rotation
    if img.mode != "RGB":
        img = img.convert("RGB")

    base = os.path.splitext(name)[0] + ".jpg"

    web = fit(img, WEB_MAX)
    web.save(os.path.join(OUT_WEB, base), "JPEG",
             quality=WEB_Q, optimize=True, progressive=True)

    full = fit(img, FULL_MAX)
    full.save(os.path.join(OUT_FULL, base), "JPEG",
              quality=FULL_Q, optimize=True, progressive=True)

    ow, oh = img.size
    ww, wh = web.size
    before = os.path.getsize(path) / 1024 / 1024
    after  = os.path.getsize(os.path.join(OUT_WEB, base)) / 1024 / 1024
    print(f"  {name}: {ow}x{oh} ({before:.1f} MB) -> {ww}x{wh} ({after:.2f} MB)")
    count += 1

print(f"\nDone. {count} file(s) processed.")
print(f"Upload BOTH '{OUT_WEB}/' and '{OUT_FULL}/' to your repo.")
