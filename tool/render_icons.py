#!/usr/bin/env python3
"""Usturlap ikonlarını SVG kaynaklarından üretir.

Kaynaklar (assets/icon/):
  usturlap_icon.svg             tam kare → iOS AppIcon (alfa kanalı yok)
  usturlap_logo.svg             yuvarlak köşeli → Android eski ikon, site
  usturlap_icon_foreground.svg  saydam → Android uyarlanabilir ikon ön yüzü

SVG'yi tarayıcıyla aynı doğrulukta çizmek için Chrome'un başsız (headless)
ekran görüntüsünü kullanır; boyutlandırmayı Pillow yapar.

Kullanım:  python3 tool/render_icons.py
Gerekenler: Google Chrome (macOS, /Applications), Pillow.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "assets" / "icon"
IOS_SET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

# Android yoğunlukları: (klasör, eski ikon px, ön yüz px). Ön yüz 108 dp tuvaldir.
ANDROID_DENSITIES = [
    ("mipmap-mdpi", 48, 108),
    ("mipmap-hdpi", 72, 162),
    ("mipmap-xhdpi", 96, 216),
    ("mipmap-xxhdpi", 144, 324),
    ("mipmap-xxxhdpi", 192, 432),
]


def render_svg(svg: Path, out: Path, profile: Path) -> Image.Image:
    """SVG'yi 1024×1024 saydam PNG olarak çizer."""
    cmd = [
        str(CHROME),
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--force-device-scale-factor=1",
        "--window-size=1024,1024",
        "--default-background-color=00000000",
        f"--user-data-dir={profile}",
        f"--screenshot={out}",
        svg.as_uri(),
    ]
    subprocess.run(cmd, check=True, capture_output=True)
    img = Image.open(out).convert("RGBA")
    if img.size != (1024, 1024):
        sys.exit(f"{svg.name}: beklenmeyen boyut {img.size}")
    return img


def resized(img: Image.Image, px: int) -> Image.Image:
    return img if img.size == (px, px) else img.resize((px, px), Image.LANCZOS)


def main() -> None:
    if not CHROME.exists():
        sys.exit(f"Chrome bulunamadı: {CHROME}")

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        profile = tmp_path / "profile"
        square = render_svg(ICON_DIR / "usturlap_icon.svg", tmp_path / "a.png", profile)
        rounded = render_svg(ICON_DIR / "usturlap_logo.svg", tmp_path / "b.png", profile)
        fg = render_svg(ICON_DIR / "usturlap_icon_foreground.svg", tmp_path / "c.png", profile)

    # iOS: App Store alfa kanallı ikonu reddeder → RGB kaydet.
    contents = json.loads((IOS_SET / "Contents.json").read_text())
    for entry in contents["images"]:
        size = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(size * scale)
        resized(square, px).convert("RGB").save(IOS_SET / entry["filename"])
    print(f"iOS: {len(contents['images'])} görsel → {IOS_SET.relative_to(ROOT)}")

    for folder, legacy_px, fg_px in ANDROID_DENSITIES:
        d = ANDROID_RES / folder
        resized(rounded, legacy_px).save(d / "ic_launcher.png")
        resized(fg, fg_px).save(d / "ic_launcher_foreground.png")
    print(f"Android: {len(ANDROID_DENSITIES)} yoğunluk → {ANDROID_RES.relative_to(ROOT)}")

    square.convert("RGB").save(ICON_DIR / "usturlap_icon_1024.png")
    print("Önizleme: assets/icon/usturlap_icon_1024.png")


if __name__ == "__main__":
    main()
