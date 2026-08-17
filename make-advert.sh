#!/usr/bin/env bash
# make-advert.sh
# Creates advert.mp4 from the images that exist in the repo using ffmpeg.
# Usage: ./make-advert.sh [output-file]
# Requirements: ffmpeg installed and available in PATH. Optional: music file music.mp3 in repo root.

set -euo pipefail

OUT=${1:-advert.mp4}
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# List of images (in the same order as the website)
images=(
  "isaac-visuals-brand-mockup.png"
  "special-sunday-service.jpg"
  "prayer-word-retreat.jpg"
  "student-forum-id-design.jpg"
  "adunni-bag-branding.jpg"
  "welcome-rollup-banner.jpg"
  "graphic-design-promo.jpg"
)

DURATION=3    # seconds per slide
RESOLUTION="1920x1080"
FONT_COLOR="white"
FONT_SIZE=48

# Check ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install ffmpeg to use this script." >&2
  exit 1
fi

echo "Creating temporary clips from images..."
idx=0
for img in "${images[@]}"; do
  if [ ! -f "$img" ]; then
    echo "Warning: $img not found — skipping." >&2
    continue
  fi

  out="$TMPDIR/clip_$idx.mp4"

  # Draw a simple caption (you can customise the text below)
  caption="Isaac Visuals — Creative Designs"

  ffmpeg -y -loop 1 -i "$img" -vf "scale=${RESOLUTION}:force_original_aspect_ratio=decrease,pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2,format=yuv420p,drawbox=x=0:y=ih-200:w=iw:h=200:color=black@0.45:t=max,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='${caption}':fontcolor=${FONT_COLOR}:fontsize=${FONT_SIZE}:x=40:y=h-140" -t ${DURATION} -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "$out"
  idx=$((idx+1))
done

# Create concat list
concat_list="$TMPDIR/concat.txt"
> "$concat_list"
for f in "$TMPDIR"/clip_*.mp4; do
  [ -e "$f" ] || continue
  echo "file '$f'" >> "$concat_list"
done

if [ ! -s "$concat_list" ]; then
  echo "No clips were created. Exiting." >&2
  exit 1
fi

# Concatenate clips
echo "Concatenating clips into ${OUT}..."
ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$TMPDIR/concat.mp4"

# If music.mp3 exists, mix audio and set to shortest
if [ -f "music.mp3" ]; then
  echo "Found music.mp3 — adding soundtrack..."
  ffmpeg -y -i "$TMPDIR/concat.mp4" -i music.mp3 -c:v copy -c:a aac -b:a 192k -shortest "$OUT"
else
  # No music — copy video
  mv "$TMPDIR/concat.mp4" "$OUT"
fi

echo "Done. Output: $OUT"

# Suggest command to open
if command -v xdg-open >/dev/null 2>&1; then
  echo "You can preview it with: xdg-open $OUT"
fi
