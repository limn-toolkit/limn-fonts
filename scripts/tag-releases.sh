#!/usr/bin/env bash
#
# Turns versions.properties into tags, so nobody types a tag name and nobody remembers a scheme.
#
# For every entry `<module>=<version>` it looks for the tag `<module>/v<version>`. Missing, the
# tag is created — annotated, at HEAD — and named in the output; present, the entry is already
# released (or staged to be) and is left alone, so running this is idempotent and running it
# after every bump is the whole workflow:
#
#   1. move the pin (scripts/fetch-fonts.sh) and the version (versions.properties), commit
#   2. ./scripts/tag-releases.sh
#   3. push, with the tags — each new tag triggers one module's publish workflow
#
# It refuses a dirty tree: a tag names a commit, and an uncommitted bump would tag a commit
# that does not carry it.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ the working tree has uncommitted changes; commit them first — a tag created now" >&2
  echo "  would point at a commit that does not carry them" >&2
  exit 1
fi

created=0
while IFS='=' read -r module version; do
  [[ -z "$module" || "$module" == \#* ]] && continue
  # Trim whitespace either side of the '='.
  module="${module%"${module##*[![:space:]]}"}"; module="${module#"${module%%[![:space:]]*}"}"
  version="${version%"${version##*[![:space:]]}"}"; version="${version#"${version%%[![:space:]]*}"}"
  tag="$module/v$version"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "· $tag already exists (bump $module in versions.properties for a new release)"
    continue
  fi
  git tag -a "$tag" -m "limn-fonts-$module $version"
  echo "✚ $tag created at $(git rev-parse --short HEAD)"
  created=$((created + 1))
done < versions.properties

if [[ $created -eq 0 ]]; then
  echo "Nothing to tag: every version in versions.properties is already tagged."
else
  echo
  echo "$created tag(s) created. Push them (GitHub Desktop pushes tags with the push);"
  echo "each one triggers its own publish run, staging one deployment on the Central Portal."
fi
