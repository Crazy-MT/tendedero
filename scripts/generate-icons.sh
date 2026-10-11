#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Assets/AppIcon.iconset Assets/Assets.xcassets/AppIcon.appiconset
swift scripts/make-icon.swift Assets/icon.png
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" Assets/icon.png --out "Assets/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z "$((s*2))" "$((s*2))" Assets/icon.png --out "Assets/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns Assets/AppIcon.iconset -o Assets/PegNest.icns
python3 - <<'PY'
from pathlib import Path
import json, shutil
root=Path('Assets/Assets.xcassets'); icons=root/'AppIcon.appiconset'
images=[]
for size in [16,32,128,256,512]:
 for scale in [1,2]:
  filename=f'icon_{size}x{size}'+('@2x' if scale==2 else '')+'.png'
  shutil.copy2(Path('Assets/AppIcon.iconset')/filename, icons/filename)
  images.append(dict(idiom='mac',size=f'{size}x{size}',scale=f'{scale}x',filename=filename))
(icons/'Contents.json').write_text(json.dumps(dict(images=images,info=dict(version=1,author='xcode')),indent=2)+'\n')
(root/'Contents.json').write_text('{"info":{"version":1,"author":"xcode"}}\n')
PY
