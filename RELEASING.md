# Releasing

Releases here are **per module**, from a tag named `<module>/v<version>` — and the tag is
derived, never typed and never pushed by hand. `versions.properties` is the single place a
version is written; the build reads it for every module's `-SNAPSHOT` default, and on every
push to main the `tag-releases` workflow reads it to create whatever tags do not exist yet and
start their publishes. Landing a bumped entry on main IS the release decision. The tree carries
no release version anywhere else: `build.gradle.kts` reads `-PlimnFontsVersion` (which the
publish workflow takes from the tag or the dispatch) and otherwise says `-SNAPSHOT`.

The version scheme: the first two components mirror the upstream release the pin points at
(Noto CJK `Sans2.004` → `2.004.x`), and the third is this repository's own — repackaging the
same upstream twice is `2.004.0` and `2.004.1`. Modules that aggregate mixed or unversionable
upstream builds (`noto-scripts`, `roboto`) version themselves plainly from `1.0.0`.

Nothing publishes itself: the upload stops as a staged deployment on the Central Portal, and the
GitHub release is drafted. Central keeps what it accepts, so the last reversible moment stays a
human pressing Publish.

## Releasing

1. **Move the pin and the version together, in one commit**: the new upstream commit + SHA-256
   in `scripts/fetch-fonts.sh` (run it with `--force` to replace the bytes), and the bumped
   entry in `versions.properties`. Let CI go green.
2. **Rehearse locally** (optional, free):
   ```
   ./gradlew :limn-fonts-noto-cjk:publishAllPublicationsToBuildDirRepository -PlimnFontsVersion=2.004.1
   ```
   With the signing key configured, every artifact under `build/repo` gets an `.asc` beside it.
3. **Push main.** The `tag-releases` workflow tags what needs tagging at the pushed commit —
   entries already tagged are left alone — and starts one `publish` run per new tag, which
   re-verifies the pins, uploads that one module's signed bundle, and drafts the GitHub release.
5. **Inspect the deployment** on <https://central.sonatype.com/publishing/deployments> — the
   last reversible moment: **Drop** discards it and costs nothing.
6. **Publish it**, then publish the draft GitHub release.
7. **If Limn should pick the new version up by default**, bump it in the main repository's
   `limn-fonts-all` POM (and wherever the guides name the coordinate) — that ships with the
   next toolkit release.

## When something goes wrong

**The publish failed after its tag was created.** Land the fix on main and delete the tag on
the web UI (repository → Tags → the tag's ⋯ menu) — the next push to main recreates it at the
fixed commit and starts publish again. Alternatively, re-run `publish` from the Actions tab
(module picked from the list, version left blank) if the tag itself is fine and only the upload
hiccuped. Once a version is published on Central its tag is frozen: publish the fix as the next
number.

**A wrong staged deployment** is Dropped on the Portal and costs nothing. **A wrong PUBLISHED
version** stays published and is superseded by the next number; there is no other move.

## Secrets

The same four repository secrets as limn-toolkit, under the same names: `MAVEN_CENTRAL_USERNAME`
and `MAVEN_CENTRAL_PASSWORD` (the Portal user token), `SIGNING_KEY` (armored private key) and
`SIGNING_PASSWORD`. The workstation copy lives outside every repository, sourced only for the
command that needs it.
