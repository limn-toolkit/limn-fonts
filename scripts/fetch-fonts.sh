#!/usr/bin/env bash
#
# The pin list for every face this repository publishes, and the only way a byte gets here.
#
# Each font is pinned to an upstream commit and verified against the SHA-256 beside it before it
# lands, so what ships is the same bytes on every machine and every day. The faces are parsed by
# stb in the toolkit's backend, which is C, so "whatever the branch serves today" is not a good
# enough answer for what gets mapped into a process. Moving a pin means changing the commit and
# the digest together — and that diff is the review a binary cannot have.
#
# A checkout has the fonts already (they are committed); this script is how they were first
# obtained, how a pin bump replaces them, and — as `--check` — how the build proves the committed
# bytes still match the pins. CI runs the check on every push and before every release.
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

# name | destination path, relative to the repository root | URL (pinned commit) | SHA-256
FONTS=(
  # Roboto is pinned to the limn-toolkit repository at an immutable commit, because that is the
  # oldest URL these exact bytes are known to live at: the four faces were vendored there from
  # the project's first commit, before this repository existed. Their provenance, as far as it
  # can be established: Roboto-Regular is BYTE-IDENTICAL to Roboto-Regular.ttf in
  # googlefonts/roboto's v2.138 release, roboto-unhinted.zip (verified 2026-09-01; that file
  # lives inside a zip asset, which this script cannot pin directly). Bold, Italic and
  # Bold-Italic name themselves "Version 2.001047; 2015" — the classic Google static build —
  # and no single-file upstream URL byte-matching them was found. If upstream ever republishes
  # them as plain files, move these pins there; until then, this pin is still commit + digest,
  # and the digests below are the review.
  "Roboto Regular (== googlefonts/roboto v2.138 unhinted)|$ROBOTO/Roboto-Regular.ttf|https://raw.githubusercontent.com/limn-toolkit/limn-toolkit/0c3ff58d8be1ef83deeee74c88373983e6c55d35/limn-backend-lwjgl/src/main/resources/limn/backend/lwjgl/fonts/Roboto-Regular.ttf|f3edb8058e523f5612bfd99d0745e661568ad85e1b6217bc62f786fabae624c6"
  "Roboto Bold (name table: Version 2.001047; 2015)|$ROBOTO/Roboto-Bold.ttf|https://raw.githubusercontent.com/limn-toolkit/limn-toolkit/0c3ff58d8be1ef83deeee74c88373983e6c55d35/limn-backend-lwjgl/src/main/resources/limn/backend/lwjgl/fonts/Roboto-Bold.ttf|61f89f8db49261c2f6106e8dccc35df7b2f7ed909020db40a3fc905e95f99334"
  "Roboto Italic (name table: Version 2.001047; 2015)|$ROBOTO/Roboto-Italic.ttf|https://raw.githubusercontent.com/limn-toolkit/limn-toolkit/0c3ff58d8be1ef83deeee74c88373983e6c55d35/limn-backend-lwjgl/src/main/resources/limn/backend/lwjgl/fonts/Roboto-Italic.ttf|fa0b17bb4aaac4a1b2ee149dd4ca3b55e97d3077aa6ba9bb02541b316e7c46ce"
  "Roboto Bold Italic (name table: Version 2.001047; 2015)|$ROBOTO/Roboto-BoldItalic.ttf|https://raw.githubusercontent.com/limn-toolkit/limn-toolkit/0c3ff58d8be1ef83deeee74c88373983e6c55d35/limn-backend-lwjgl/src/main/resources/limn/backend/lwjgl/fonts/Roboto-BoldItalic.ttf|40083ed54338397cf49d2c49f59eddcd963a30fdb301813d4bd3abbb37a13d12"
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

status=0
for entry in "${FONTS[@]}"; do
  IFS='|' read -r name file url sha <<< "$entry"
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
  curl -fSL --retry 3 --max-time 300 -o "$target.part" "$url"
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
