# Releasing

Releases here are **per module**, from a tag named `<module>/v<version>` — and the tag is
derived, never typed. `versions.properties` is the single place a version is written; the build
reads it for every module's `-SNAPSHOT` default, and `scripts/tag-releases.sh` reads it to
create whatever tags do not exist yet. The tree carries no release version anywhere else:
`build.gradle.kts` reads `-PlimnFontsVersion` (which the publish workflow takes from the tag)
and otherwise says `-SNAPSHOT`.

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
3. **Run `./scripts/tag-releases.sh`.** It tags what needs tagging (annotated, at HEAD), tells
   you what it created, and is idempotent — versions already tagged are left alone.
4. **Push, with the tags.** Each new tag triggers one `publish` run, which re-verifies the pins,
   uploads that one module's signed bundle, and drafts the GitHub release.
5. **Inspect the deployment** on <https://central.sonatype.com/publishing/deployments> — the
   last reversible moment: **Drop** discards it and costs nothing.
6. **Publish it**, then publish the draft GitHub release.
7. **If Limn should pick the new version up by default**, bump it in the main repository's
   `limn-fonts-all` POM (and wherever the guides name the coordinate) — that ships with the
   next toolkit release.

## When something goes wrong

Same rules as the main repository: a failed build after the tag can be fixed and re-tagged
(`git tag -f`, force-push the tag) as long as nothing was published under it; a wrong staged
deployment is Dropped and costs nothing; a wrong PUBLISHED version stays published and is
superseded by the next number.

## Secrets

The same four repository secrets as limn-toolkit, under the same names: `MAVEN_CENTRAL_USERNAME`
and `MAVEN_CENTRAL_PASSWORD` (the Portal user token), `SIGNING_KEY` (armored private key) and
`SIGNING_PASSWORD`. The workstation copy lives outside every repository, sourced only for the
command that needs it.
