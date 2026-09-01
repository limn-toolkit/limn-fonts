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
CJK="limn-fonts-noto-cjk/src/main/resources/limn/fonts"
EMOJI="limn-fonts-noto-emoji/src/main/resources/limn/fonts"
SCRIPTS="limn-fonts-noto-scripts/src/main/resources/limn/fonts"
MODE="${1:-}"

# name | destination path, relative to the repository root | URL (pinned commit) | SHA-256
FONTS=(
  "Noto Sans CJK (pan-CJK: Han + Kana + Hangul + Latin/Greek/Cyrillic), tag Sans2.004|$CJK/NotoSansCJK-Regular.otf|https://raw.githubusercontent.com/notofonts/noto-cjk/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf|68a3fc98800b2a27b371f2fb79991daf3633bd89309d4ffaa6946fd587f375b5"
  "Noto Color Emoji (CBDT color bitmaps), tag v2.051|$EMOJI/NotoColorEmoji.ttf|https://raw.githubusercontent.com/googlefonts/noto-emoji/8998f5dd683424a73e2314a8c1f1e359c19e8742/fonts/NotoColorEmoji.ttf|72a635cb3d2f3524c51620cdde406b217204e8a6a06c6a096ff8ed4b5fd6e27b"
  # The four complex scripts, from notofonts.github.io at one pinned commit, Regular and Bold
  # from the SAME commit so a mixed-weight paragraph never mixes upstream builds of one family.
  # hinted/ttf is upstream's default distribution build (stb executes no TrueType bytecode and
  # applies no variations, so neither hinting nor the variable font would change a pixel).
  "Noto Sans Arabic Regular (Arabic: contextual forms, ligatures, RTL)|$SCRIPTS/NotoSansArabic-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Regular.ttf|bdff3e5659d67e67def05b33f749683b9376ae819d65d3dd62ac4640b3aaef48"
  "Noto Sans Arabic Bold|$SCRIPTS/NotoSansArabic-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Bold.ttf|4e5462d2e8be880317b9f49b5b2da109ddb6a3563d91cc604b67f3535832a555"
  "Noto Sans Hebrew Regular (Hebrew: RTL, GPOS-placed points)|$SCRIPTS/NotoSansHebrew-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansHebrew/hinted/ttf/NotoSansHebrew-Regular.ttf|cdefaf8efd47045f6820928eba84db5bed7557539328952b5f828315485e02ee"
  "Noto Sans Hebrew Bold|$SCRIPTS/NotoSansHebrew-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansHebrew/hinted/ttf/NotoSansHebrew-Bold.ttf|da9226e886c245a7e11673c24dec82bded64d8574c1e1f03983bf89297d2aaa8"
  "Noto Sans Devanagari Regular (Devanagari: conjuncts, matra reordering)|$SCRIPTS/NotoSansDevanagari-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansDevanagari/hinted/ttf/NotoSansDevanagari-Regular.ttf|306b53ecfb182a504dd8a7446093c316387d2fd8dc350d0792ed1753fe0996cd"
  "Noto Sans Devanagari Bold|$SCRIPTS/NotoSansDevanagari-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansDevanagari/hinted/ttf/NotoSansDevanagari-Bold.ttf|3ad8362a06271814869838dcc3d161b13c9fb97681b627af1f7f283ea9387d56"
  "Noto Sans Thai Regular (Thai: mark stacking, and no spaces to break at)|$SCRIPTS/NotoSansThai-Regular.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansThai/hinted/ttf/NotoSansThai-Regular.ttf|61cf814eec46b294d6ea4401ac295d0cecd5207bd2331dcc5a15e7301d30ee44"
  "Noto Sans Thai Bold|$SCRIPTS/NotoSansThai-Bold.ttf|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/NotoSansThai/hinted/ttf/NotoSansThai-Bold.ttf|2ac6c6e8a478e23b15f76e4894af1fa2210f8f350e4e6e54aad530bec03efbfb"
  # ONE licence for the four: notofonts.github.io publishes a single SIL OFL 1.1 at the root of
  # its fonts/ tree that covers every family under it.
  "Noto Sans script faces licence (SIL OFL 1.1, covers all four)|$SCRIPTS/NotoSansScripts-LICENSE.txt|https://raw.githubusercontent.com/notofonts/notofonts.github.io/3a06b1c521155492df224d33464b3c7b2852d861/fonts/LICENSE|f2095b08bed08b23a6fe26112fcd679a2bee3f002eef077eb05d215ed1051bd8"
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
