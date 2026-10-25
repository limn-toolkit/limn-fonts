#!/usr/bin/env bash
#
# The pin list for every face this repository publishes, and the only way a byte gets here.
#
# Each font is pinned to an upstream commit or release and verified against the SHA-256 beside it
# before it lands, so what ships is the same bytes on every machine and every day. The faces are
# parsed by stb in the toolkit's backend, which is C, so "whatever the branch serves today" is not
# a good enough answer for what gets mapped into a process. Moving a pin means changing the URL
# and the digest together — and that diff is the review a binary cannot have.
#
# A face upstream publishes only inside a zip release asset is pinned twice: the zip by its URL
# and digest (ZIPS below), and the file by its name inside the zip and its own digest (its entry
# in FONTS). A run downloads each zip it needs once, to a temporary directory, and takes nothing
# out of a zip that does not match its pin; the member then has to match its own pin before it
# is moved in, like any other face.
#
# A checkout has the fonts already (they are committed); this script is how they were first
# obtained, how a pin bump replaces them, and — as `--check` — how the build proves the committed
# bytes still match the pins. CI runs the check on every push and before every release. The check
# reads only the committed files, which are byte for byte what their pins name, so it needs
# neither the network nor a zip.
#
# Usage:
#   ./scripts/fetch-fonts.sh            fetch whatever is missing, verify whatever is present
#   ./scripts/fetch-fonts.sh --force    replace present files with the pinned builds
#   ./scripts/fetch-fonts.sh --check    verify only: no network, missing or mismatched fails
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROBOTO="limn-fonts-roboto/src/main/resources/limn/fonts"
CJK="limn-fonts-noto-cjk/src/main/resources/limn/fonts"
EMOJI="limn-fonts-noto-emoji/src/main/resources/limn/fonts"
SCRIPTS="limn-fonts-noto-scripts/src/main/resources/limn/fonts"
MODE="${1:-}"

# Zip release assets a face is taken from: URL | SHA-256 of the zip itself.
ROBOTO_ZIP="https://github.com/googlefonts/roboto-2/releases/download/v2.138/roboto-unhinted.zip"
ZIPS=(
  "$ROBOTO_ZIP|70f64c718510a601fbcf752aafe644314dacaeb85474dc689c89787c4a72a728"
)

# name | destination path, relative to the repository root | URL (pinned commit or release)
#   | SHA-256 [ | member ]. With the fifth field, the URL is a zip in ZIPS, the member is the
#   file's name inside it, and the SHA-256 is the member's, which is the committed file's too.
FONTS=(
  # Roboto is upstream's v2.138 (googlefonts/roboto-2, Apache License 2.0), the last release of
  # Roboto 2, made 2017-08-02 in a repository since archived. The release ships its faces only
  # inside zip assets, so the four and the licence are members of roboto-unhinted.zip, pinned in
  # ZIPS above. Unhinted because v2.138 has no hinted desktop build, and stb executes no TrueType
  # bytecode, so hinting would change no pixel. Until 2.138.0 this module carried the faces the
  # toolkit vendored before this repository existed: the same Regular and licence, byte for
  # byte, beside a Bold, Italic and Bold-Italic from a 2015 build ("Version 2.001047; 2015")
  # whose hhea ascent and descent (2146/-555) disagreed with Regular's (1900/-500). The v2.138
  # four are one build: the same vertical metrics, the same 3,387 glyphs, the same code points.
  "Roboto Regular, v2.138 unhinted|$ROBOTO/Roboto-Regular.ttf|$ROBOTO_ZIP|f3edb8058e523f5612bfd99d0745e661568ad85e1b6217bc62f786fabae624c6|Roboto-Regular.ttf"
  "Roboto Bold, v2.138 unhinted|$ROBOTO/Roboto-Bold.ttf|$ROBOTO_ZIP|2ca2b3bfc2c2d43fa8f2b7227982d735fd537ecf113a4c56cc2d292bcc3106c8|Roboto-Bold.ttf"
  "Roboto Italic, v2.138 unhinted|$ROBOTO/Roboto-Italic.ttf|$ROBOTO_ZIP|2b4076dd3f5a7fadfca760ef45557a0d437af983284652fc149535c5bd93d493|Roboto-Italic.ttf"
  "Roboto Bold Italic, v2.138 unhinted|$ROBOTO/Roboto-BoldItalic.ttf|$ROBOTO_ZIP|03ccd7a9d4493577d5b7da5440d01a24bd4f6bf05f48c2e114ef24b752859323|Roboto-BoldItalic.ttf"
  # The release's own licence file, the one text that covers the four.
  "Roboto licence (Apache License 2.0, covers all four)|$ROBOTO/Roboto-LICENSE.txt|$ROBOTO_ZIP|c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4|LICENSE"
  "Noto Sans CJK (pan-CJK: Han + Kana + Hangul + Latin/Greek/Cyrillic), tag Sans2.004|$CJK/NotoSansCJK-Regular.otf|https://raw.githubusercontent.com/notofonts/noto-cjk/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf|68a3fc98800b2a27b371f2fb79991daf3633bd89309d4ffaa6946fd587f375b5"
  "Noto Color Emoji (CBDT color bitmaps), 2D v2.057 from tag v2026-09-24-unicode18_0 (Unicode 18.0)|$EMOJI/NotoColorEmoji.ttf|https://raw.githubusercontent.com/googlefonts/noto-emoji/e20cbc2bbec1926686be9f9bee7d1d2cfa1fea0e/2D/fonts/NotoColorEmoji.ttf|15671215ab769fdc7162a045d56fd7d7e477c51b04e6b3c761d914d8fdd6cc44"
  # The four complex scripts, from notofonts.github.io at one pinned commit, Regular and Bold
  # from the SAME commit so a mixed-weight paragraph never mixes upstream builds of one family.
  # hinted/ttf is upstream's default distribution build (stb executes no TrueType bytecode and
  # applies no variations, so neither hinting nor the variable font would change a pixel).
  "Noto Sans Arabic Regular (Arabic: contextual forms, ligatures, RTL)|$SCRIPTS/NotoSansArabic-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Regular.ttf|bdff3e5659d67e67def05b33f749683b9376ae819d65d3dd62ac4640b3aaef48"
  "Noto Sans Arabic Bold|$SCRIPTS/NotoSansArabic-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Bold.ttf|4e5462d2e8be880317b9f49b5b2da109ddb6a3563d91cc604b67f3535832a555"
  "Noto Sans Hebrew Regular (Hebrew: RTL, GPOS-placed points)|$SCRIPTS/NotoSansHebrew-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansHebrew/hinted/ttf/NotoSansHebrew-Regular.ttf|cdefaf8efd47045f6820928eba84db5bed7557539328952b5f828315485e02ee"
  "Noto Sans Hebrew Bold|$SCRIPTS/NotoSansHebrew-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansHebrew/hinted/ttf/NotoSansHebrew-Bold.ttf|da9226e886c245a7e11673c24dec82bded64d8574c1e1f03983bf89297d2aaa8"
  "Noto Sans Devanagari Regular (Devanagari: conjuncts, matra reordering)|$SCRIPTS/NotoSansDevanagari-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansDevanagari/hinted/ttf/NotoSansDevanagari-Regular.ttf|4e3c66638958c3e2ab5d37f47a8deb89fffeb7be9985c665a519bbc7ba762313"
  "Noto Sans Devanagari Bold|$SCRIPTS/NotoSansDevanagari-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansDevanagari/hinted/ttf/NotoSansDevanagari-Bold.ttf|6a09c8d797cfc803d32cdc731e809424d74cbaff59f503de34ade421a08e5bc2"
  "Noto Sans Thai Regular (Thai: mark stacking, and no spaces to break at)|$SCRIPTS/NotoSansThai-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansThai/hinted/ttf/NotoSansThai-Regular.ttf|61cf814eec46b294d6ea4401ac295d0cecd5207bd2331dcc5a15e7301d30ee44"
  "Noto Sans Thai Bold|$SCRIPTS/NotoSansThai-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/NotoSansThai/hinted/ttf/NotoSansThai-Bold.ttf|2ac6c6e8a478e23b15f76e4894af1fa2210f8f350e4e6e54aad530bec03efbfb"
  # ONE licence for the four: notofonts.github.io publishes a single SIL OFL 1.1 at the root of
  # its fonts/ tree that covers every family under it.
  "Noto Sans script faces licence (SIL OFL 1.1, covers all four)|$SCRIPTS/NotoSansScripts-LICENSE.txt|https://raw.githubusercontent.com/notofonts/notofonts.github.io/f145d86c53996717bc4c25d4602eb9294e43dccc/fonts/LICENSE|f2095b08bed08b23a6fe26112fcd679a2bee3f002eef077eb05d215ed1051bd8"
)

digest_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}

# Points zip_path at a verified local copy of the zip at URL $1, downloading it the first time a
# run asks. The copies live in one temporary directory, removed when the script exits; a zip that
# failed its pin leaves a marker there, so the members after the first do not download it again.
work=""
zip_path=""
fetch_zip() {
  local url="$1" i=0 found="" entry zurl zsha actual
  zip_path=""
  for entry in "${ZIPS[@]}"; do
    IFS='|' read -r zurl zsha <<< "$entry"
    if [[ "$zurl" == "$url" ]]; then
      found=1
      break
    fi
    i=$((i + 1))
  done
  if [[ -z "$found" ]]; then
    echo "✗ $url is not pinned in ZIPS" >&2
    return 1
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    echo "✗ unzip is needed to take a face out of $url" >&2
    return 1
  fi
  if [[ -z "$work" ]]; then
    work="$(mktemp -d "${TMPDIR:-/tmp}/fetch-fonts.XXXXXX")" || return 1
    trap 'rm -rf "$work"' EXIT
  fi
  zip_path="$work/$i.zip"
  if [[ -f "$zip_path" ]]; then
    return 0
  fi
  if [[ -f "$work/$i.failed" ]]; then
    return 1
  fi
  echo "  ↓ $url"
  if ! curl -fSL --retry 3 --max-time 300 -o "$zip_path.part" "$url"; then
    touch "$work/$i.failed"
    return 1
  fi
  actual="$(digest_of "$zip_path.part")"
  if [[ "$actual" != "$zsha" ]]; then
    echo "✗ $url is not what its pin says it is" >&2
    echo "  expected $zsha" >&2
    echo "  got      $actual" >&2
    touch "$work/$i.failed"
    return 1
  fi
  mv "$zip_path.part" "$zip_path"
}

status=0
for entry in "${FONTS[@]}"; do
  IFS='|' read -r name file url sha member <<< "$entry"
  target="$ROOT/$file"
  if [[ "$MODE" == "--check" ]]; then
    if [[ ! -f "$target" ]]; then
      echo "✗ $file is missing (run scripts/fetch-fonts.sh)" >&2
      status=1
    elif [[ "$(digest_of "$target")" != "$sha" ]]; then
      echo "✗ $file does not match its pin" >&2
      status=1
    else
      echo "✓ $name"
    fi
    continue
  fi
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" && "$MODE" != "--force" ]]; then
    if [[ "$(digest_of "$target")" == "$sha" ]]; then
      echo "✓ $name already present ($file)"
      continue
    fi
    echo "✗ $file is present but is not the pinned build; pass --force to replace it" >&2
    status=1
    continue
  fi
  echo "↓ $name → $file"
  # Downloaded beside the target and moved in only once it verifies: a font that fails the
  # digest must not be left where the jar would package it.
  if [[ -n "$member" ]]; then
    if ! fetch_zip "$url"; then
      echo "✗ $file was not fetched: its zip did not arrive as pinned" >&2
      status=1
      continue
    fi
    if ! unzip -p "$zip_path" "$member" > "$target.part"; then
      echo "✗ $member could not be read out of $url" >&2
      rm -f "$target.part"
      status=1
      continue
    fi
  else
    curl -fSL --retry 3 --max-time 300 -o "$target.part" "$url"
  fi
  actual="$(digest_of "$target.part")"
  if [[ "$actual" != "$sha" ]]; then
    echo "✗ $file is not what the pin says it is" >&2
    echo "  expected $sha" >&2
    echo "  got      $actual" >&2
    rm -f "$target.part"
    status=1
    continue
  fi
  mv "$target.part" "$target"
  echo "  saved $(du -h "$target" | cut -f1)"
done
if [[ $status -ne 0 ]]; then
  [[ "$MODE" == "--check" ]] && echo "The committed fonts do not match the pins." >&2 \
      || echo "Some fonts were not fetched." >&2
  exit $status
fi
echo "All faces match their pins."
