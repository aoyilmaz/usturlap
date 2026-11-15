#!/usr/bin/env python3
"""Site için ekran görüntüsü ve video çeker (iOS simülatörü).

integration_test/showcase_test.dart uygulamayı simülatörde demo verisiyle
gezdirir ve şu satırları yazar:
  SHOT:<ad>          → ekran görüntüsü  → <out>/shots/<ad>.webp
  VIDEO:start:<ad>   → video kaydı başlar
  VIDEO:stop         → kayıt biter       → <out>/video/<ad>.mp4 + <ad>.webp (afiş)

Kullanım:
  python3 tool/capture_site_media.py                       # website/assets
  python3 tool/capture_site_media.py --out /tmp/deneme --test integration_test/showcase_test.dart

Gerekenler: Xcode (simctl, swiftc), cwebp, dart_defines.json (Mapbox anahtarı).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FLUTTER = Path.home() / "development" / "flutter" / "bin" / "flutter"
# Afiş karesi (sn; eksi: sondan). Varsayılan videonun başı.
POSTER_AT = {"cizim": "-0.8"}
MARK = re.compile(r"(SHOT:[\w-]+|VIDEO:start:[\w-]+|VIDEO:stop|VIDEO:abort)")


def sh(*cmd: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def stop_recorder(rec: "subprocess.Popen | None") -> None:
    """simctl recordVideo SIGINT ile dosyayı kapatıp çıkar."""
    if rec is None or rec.poll() is not None:
        return
    rec.send_signal(signal.SIGINT)
    try:
        rec.wait(timeout=30)
    except subprocess.TimeoutExpired:
        rec.kill()


def find_device(name: str) -> str:
    data = json.loads(sh("xcrun", "simctl", "list", "devices", "available", "-j").stdout)
    for devices in data["devices"].values():
        for d in devices:
            if d["name"] == name:
                return d["udid"]
    sys.exit(f"Simülatör bulunamadı: {name}")


def prepare(udid: str) -> None:
    sh("xcrun", "simctl", "boot", udid, check=False)  # zaten açıksa hata verir
    sh("xcrun", "simctl", "bootstatus", udid, "-b")
    sh("xcrun", "simctl", "ui", udid, "appearance", "dark")
    # Temiz durum çubuğu: 09:41, dolu pil, şebeke göstergeleri sabit.
    sh(
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "09:41", "--batteryState", "charged", "--batteryLevel", "100",
        "--cellularMode", "active", "--cellularBars", "4", "--wifiBars", "3",
        "--operatorName", "",
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="iPhone 17 Pro Max")
    ap.add_argument("--out", default=str(ROOT / "website" / "assets"))
    ap.add_argument("--test", default="integration_test/showcase_test.dart")
    ap.add_argument("--width", type=int, default=800, help="görüntü genişliği (px)")
    ap.add_argument("--only", default="", help="yalnız bu adımlar (virgülle), ör. tur,rota")
    ap.add_argument("--raw", default=str(ROOT / "build" / "site_media_ham"),
                    help="ham görüntü / video ve günlük klasörü")
    args = ap.parse_args()

    out = Path(args.out)
    # Ham PNG / MOV büyük: sitenin dışında (build/ git'e girmez).
    raw = Path(args.raw)
    for d in (out / "shots", out / "video", raw):
        d.mkdir(parents=True, exist_ok=True)

    # Video kodlayıcı (AVFoundation; ffmpeg gerekmez) bir kez derlenir.
    encoder = raw / "encode_video"
    r = sh("swiftc", "-O", "-o", str(encoder), str(ROOT / "tool" / "encode_video.swift"), check=False)
    if r.returncode != 0:
        sys.exit("tool/encode_video.swift derlenemedi:\n" + r.stderr[-2000:])

    udid = find_device(args.device)
    prepare(udid)
    print(f"Simülatör: {args.device} ({udid})")

    cmd = [
        str(FLUTTER), "test", args.test, "-d", udid,
        "--dart-define-from-file=dart_defines.json",
    ]
    if args.only:
        cmd.append(f"--dart-define=ONLY={args.only}")
    proc = subprocess.Popen(
        cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )
    recorder: subprocess.Popen | None = None
    video_name = ""
    shots: list[str] = []
    videos: list[str] = []
    log = (raw / "test.log").open("w")

    assert proc.stdout is not None
    for line in proc.stdout:
        log.write(line)
        m = MARK.search(line)
        if not m:
            if "error" in line.lower() or "fail" in line.lower() or "Exception" in line:
                print("  │ " + line.rstrip())
            continue
        mark = m.group(1)
        if mark.startswith("SHOT:"):
            name = mark[5:]
            png = raw / f"{name}.png"
            sh("xcrun", "simctl", "io", udid, "screenshot", "--type=png", str(png))
            # Hata anı görüntüleri siteye değil ham klasöre (inceleme için).
            dest = raw if name.startswith("hata-") else out / "shots"
            sh("cwebp", "-quiet", "-q", "82", "-resize", str(args.width), "0",
               str(png), "-o", str(dest / f"{name}.webp"))
            shots.append(name)
            print(f"  ▣ {name}")
        elif mark.startswith("VIDEO:start:"):
            stop_recorder(recorder)  # önceki kayıt yarıda kaldıysa
            video_name = mark[len("VIDEO:start:"):]
            mov = raw / f"{video_name}.mov"
            recorder = subprocess.Popen(
                ["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264",
                 "--force", str(mov)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            print(f"  ● {video_name} kaydı başladı")
        elif mark == "VIDEO:abort":
            stop_recorder(recorder)
            recorder = None
            print(f"  ✕ {video_name} kaydı iptal (adım hata verdi)")
        elif mark == "VIDEO:stop" and recorder is not None:
            stop_recorder(recorder)
            recorder = None
            mov = raw / f"{video_name}.mov"
            mp4 = out / "video" / f"{video_name}.mp4"
            poster = raw / f"{video_name}-afis.png"
            # Test kayıt başlayınca 2 sn, bitirmeden 0,8 sn bekler: kırpılır.
            r = sh(str(encoder), str(mov), str(mp4), "--width", "444", "--kbps", "1400",
                   "--fps", "30", "--trim-start", "1.6", "--trim-end", "0.6",
                   "--poster", str(poster), "--poster-at", POSTER_AT.get(video_name, "0.2"), check=False)
            if r.returncode == 0:
                sh("cwebp", "-quiet", "-q", "80", str(poster),
                   "-o", str(out / "video" / f"{video_name}.webp"))
                videos.append(video_name)
                print(f"  ■ {video_name} → {r.stdout.strip()}")
            else:
                print(f"  ✕ {video_name} dönüştürülemedi: {(r.stderr or r.stdout).strip()[:300]}")

    proc.wait()
    log.close()
    stop_recorder(recorder)
    print(f"\n{len(shots)} görüntü, {len(videos)} video. Test çıkış kodu: {proc.returncode}")
    print(f"Ham dosyalar ve günlük: {raw}")
    sys.exit(proc.returncode)


if __name__ == "__main__":
    if not shutil.which("cwebp"):
        sys.exit("cwebp yok (brew install webp)")
    os.chdir(ROOT)
    main()
