#!/usr/bin/env python3
"""Pusula — geliştirme testi için SENTETİK bir MBTiles üretir.

Ağdan karo İNDİRMEZ. Her karoyu yerel olarak (Pillow ile) çizer: zoom'a göre
renk, kenar ızgarası ve ortada "z/x/y" etiketi. Amaç, çevrimdışı MBTiles boru
hattını (SQLite → flutter_map → ekran) hiçbir lisans/ağ sorunu olmadan
doğrulamak. Kaydırınca/yakınlaştırınca karoların gerçekten yerel dosyadan
geldiğini etiketlerden net görürsün.

Gerçek harita karolarını sonra QGIS + gdal2tiles ile üretip assets/tiles/
altına koyacağız; bu script sadece "kod çalışıyor mu" testi içindir.

MBTiles: metadata(name,value) +
tiles(zoom_level, tile_column, tile_row, tile_data).
MBTiles y eksenini TMS ile saklar: tms_y = (2^z - 1) - xyz_y
"""

import io
import math
import os
import sqlite3

from PIL import Image, ImageDraw, ImageFont

CENTER_LAT, CENTER_LON = 39.925, 32.866  # Ankara (constants.dart ile aynı)
HALF_DEG = 0.12
ZOOMS = range(10, 15)  # 10..14
TILE = 256
OUT = os.path.join("assets", "tiles", "ankara_osm.mbtiles")

# Zoom'a göre arka plan rengi (açıktan koyuya doğru hafif tonlar).
ZOOM_BG = {
    10: (235, 240, 245),
    11: (225, 235, 230),
    12: (235, 230, 220),
    13: (230, 225, 235),
    14: (220, 235, 235),
}


def deg2num(lat, lon, z):
    lat_rad = math.radians(lat)
    n = 2 ** z
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


def num2deg(x, y, z):
    n = 2 ** z
    lon = x / n * 360.0 - 180.0
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    return lat, lon


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # eski Pillow
        return ImageFont.load_default()


def make_tile(z, x, y, is_center):
    img = Image.new("RGB", (TILE, TILE), ZOOM_BG.get(z, (230, 230, 230)))
    d = ImageDraw.Draw(img)
    # kenar ızgarası (komşuluk görünsün)
    d.rectangle([0, 0, TILE - 1, TILE - 1], outline=(150, 160, 170), width=2)
    for g in (64, 128, 192):
        d.line([(g, 0), (g, TILE)], fill=(205, 210, 215))
        d.line([(0, g), (TILE, g)], fill=(205, 210, 215))
    # crosshair
    d.line([(TILE // 2, 118), (TILE // 2, 138)], fill=(120, 130, 140))
    d.line([(118, TILE // 2), (138, TILE // 2)], fill=(120, 130, 140))
    # z/x/y etiketi
    d.text((10, 8), f"z{z}", font=font(22), fill=(40, 60, 90))
    d.text((10, 40), f"x={x}", font=font(16), fill=(60, 70, 80))
    d.text((10, 60), f"y={y}", font=font(16), fill=(60, 70, 80))
    lat, lon = num2deg(x, y, z)
    d.text((10, TILE - 24), f"{lat:.3f},{lon:.3f}", font=font(13),
           fill=(90, 100, 110))
    # merkez (Ankara) karosunu vurgula
    if is_center:
        d.ellipse([TILE // 2 - 8, TILE // 2 - 8, TILE // 2 + 8, TILE // 2 + 8],
                  fill=(220, 40, 40))
        d.text((TILE // 2 + 12, TILE // 2 - 8), "ANKARA", font=font(14),
               fill=(180, 30, 30))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)

    conn = sqlite3.connect(OUT)
    c = conn.cursor()
    c.execute("CREATE TABLE metadata (name text, value text);")
    c.execute(
        "CREATE TABLE tiles (zoom_level integer, tile_column integer, "
        "tile_row integer, tile_data blob);"
    )
    c.execute(
        "CREATE UNIQUE INDEX tile_index on tiles "
        "(zoom_level, tile_column, tile_row);"
    )
    meta = {
        "name": "Ankara (sentetik test)",
        "type": "baselayer",
        "version": "1.0",
        "description": "Pusula dev test karolari (yerel uretildi)",
        "format": "png",
        "minzoom": str(min(ZOOMS)),
        "maxzoom": str(max(ZOOMS)),
        "bounds": f"{CENTER_LON-HALF_DEG},{CENTER_LAT-HALF_DEG},"
        f"{CENTER_LON+HALF_DEG},{CENTER_LAT+HALF_DEG}",
    }
    for k, v in meta.items():
        c.execute("INSERT INTO metadata VALUES (?,?)", (k, v))

    count = 0
    for z in ZOOMS:
        cx, cy = deg2num(CENTER_LAT, CENTER_LON, z)
        x_west, _ = deg2num(CENTER_LAT, CENTER_LON - HALF_DEG, z)
        x_east, _ = deg2num(CENTER_LAT, CENTER_LON + HALF_DEG, z)
        _, y_north = deg2num(CENTER_LAT + HALF_DEG, CENTER_LON, z)
        _, y_south = deg2num(CENTER_LAT - HALF_DEG, CENTER_LON, z)
        for x in range(x_west, x_east + 1):
            for y in range(y_north, y_south + 1):
                data = make_tile(z, x, y, is_center=(x == cx and y == cy))
                tms_y = (2 ** z - 1) - y
                c.execute(
                    "INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)",
                    (z, x, tms_y, sqlite3.Binary(data)),
                )
                count += 1
        conn.commit()
        print(f"  z={z} bitti, toplam {count} karo")

    conn.close()
    size_kb = os.path.getsize(OUT) // 1024
    print(f"Tamam: {OUT} ({count} karo, {size_kb} KB)")


if __name__ == "__main__":
    main()
