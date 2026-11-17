#!/bin/zsh
# Rigenera le icone dell'app da Branding/AppIcon-1024.png (esportato da Affinity).
# Uso: zsh Branding/make_icon.sh
set -e
cd "$(dirname "$0")/.."
D=Dillo/Assets.xcassets/AppIcon.appiconset
for pt in 16 32 128 256 512; do
  for sc in 1 2; do
    px=$((pt * sc))
    suffix=""; [ $sc = 2 ] && suffix="@2x"
    name=icon_${pt}x${pt}${suffix}.png
    sips -z $px $px Branding/AppIcon-1024.png --out $D/$name >/dev/null
  done
done
echo "Icone aggiornate in $D"
