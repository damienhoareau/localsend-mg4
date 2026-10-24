#!/usr/bin/env bash
# Runs inside the Android emulator (started by reactivecircus/android-emulator-runner).
# Installs the x86_64 APK, launches the app at head-unit-like resolution and saves
# screenshots of the Receive / Send / Settings tabs + UI dumps + logcat to $OUT.
#
# Navigation uses `uiautomator dump`: Flutter exposes its widgets as accessibility nodes,
# so tabs are found by label instead of by guessed coordinates. If a tab is not found,
# its screenshot is simply skipped (see notes.txt in the output).
set -u
APK="$1"
OUT="${2:-preview-out}"
PKG=org.localsend.localsend_app.mg4
ACT=org.localsend.localsend_app.MainActivity
mkdir -p "$OUT"
NOTES="$OUT/notes.txt"
: > "$NOTES"

shot() { adb exec-out screencap -p > "$OUT/$1.png" || true; }

# uiautomator dump can fail while the app is animating: retry a few times.
dump_ui() {
  for i in 1 2 3 4 5 6; do
    if adb shell uiautomator dump /sdcard/ui.xml 2>&1 | grep -q "dumped to"; then
      adb pull /sdcard/ui.xml "$1" >/dev/null 2>&1 && return 0
    fi
    sleep 3
  done
  return 1
}

# Prints "x y" (centre) of the first node whose text / content-desc starts with the given regex.
find_node() {
  python3 - "$1" "$2" <<'PY'
import html, re, sys
xml = open(sys.argv[1], encoding="utf-8").read()
pat = re.compile(r"^\s*(?:%s)\b" % sys.argv[2], re.I)
for m in re.finditer(r"<node [^>]*>", xml):
    node = m.group(0)
    text = re.search(r'\btext="([^"]*)"', node)
    desc = re.search(r'content-desc="([^"]*)"', node)
    bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
    if not bounds:
        continue
    for label in ((text.group(1) if text else ""), (desc.group(1) if desc else "")):
        if pat.search(html.unescape(label)):
            l, t, r, b = map(int, bounds.groups())
            print((l + r) // 2, (t + b) // 2)
            sys.exit(0)
PY
}

# Taps the tab whose label matches $1 (regex), then takes the screenshot named $2.
open_tab() {
  local dump="$OUT/ui-before-$2.xml"
  if dump_ui "$dump"; then
    local xy
    xy="$(find_node "$dump" "$1")"
    if [ -n "$xy" ]; then
      adb shell input tap $xy
      sleep 6
      shot "$2"
      echo "$2: tapped '$1' at $xy" >> "$NOTES"
      return 0
    fi
  fi
  echo "$2: tab '$1' not found, screenshot skipped" >> "$NOTES"
  return 1
}

# Area LocalSend gets on the head unit (about 90% of the 1920x720 panel, estimated from photos).
# Hide the emulator's own status/navigation bars: the head unit has none in that area.
adb shell wm size "${SCREEN_SIZE:-1744x640}"
adb shell wm density "${SCREEN_DENSITY:-160}"
adb shell settings put global policy_control "immersive.full=*" || true

adb install -r "$APK" || { echo "install failed" | tee -a "$NOTES"; exit 1; }
for perm in READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION; do
  adb shell pm grant "$PKG" "android.permission.$perm" || true
done

adb shell am start -n "$PKG/$ACT" || adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 30
shot 01-receive
dump_ui "$OUT/ui-01-receive.xml" || echo "01-receive: ui dump failed" >> "$NOTES"

open_tab 'Send|Envoyer' 02-send || true
open_tab 'Settings|Paramètres' 03-settings || true

# The emulator screenshot is the full 1080x1920 panel with the (smaller) overridden display letterboxed
# in black: crop it so the pictures only show the app area. Best effort, the originals stay if it fails.
python3 -m pip install --quiet pillow >/dev/null 2>&1 || true
python3 - "$OUT" <<'PY' || echo "crop skipped" >> "$NOTES"
import glob, sys
from PIL import Image, ImageChops
for path in sorted(glob.glob(sys.argv[1] + "/0[0-9]-*.png")):
    img = Image.open(path).convert("RGB")
    bbox = ImageChops.difference(img, Image.new("RGB", img.size, (0, 0, 0))).getbbox()
    if bbox:
        img.crop(bbox).save(path)
PY

adb logcat -d -t 4000 > "$OUT/logcat.txt" || true
{ adb shell wm size; adb shell wm density; adb shell getprop ro.build.version.release; } > "$OUT/screen.txt"
echo "done" | tee -a "$NOTES"
