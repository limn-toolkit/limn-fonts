# Releasing

Releases here are **per module**. The tag names both the module and the version, and is the only
place a version exists: `build.gradle.kts` reads `-PlimnFontsVersion` and otherwise says
`-SNAPSHOT`, so a release edits no file.

```
noto-cjk/v2.004.0        → limn-fonts-noto-cjk 2.004.0
noto-emoji/v2.051.0      → limn-fonts-noto-emoji 2.051.0
noto-scripts/v1.0.0      → limn-fonts-noto-scripts 1.0.0
```

The version scheme: the first two components mirror the upstream release the pin points at
(Noto CJK `Sans2.004` → `2.004.x`), and the third is this repository's own — repackaging the
same upstream twice is `2.004.0` and `2.004.1`. `noto-scripts` aggregates four families pinned
to one commit and versions itself plainly from `1.0.0`.

Nothing publishes itself: the upload stops as a staged deployment on the Central Portal, and the
GitHub release is drafted. Central keeps what it accepts, so the last reversible moment stays a
human pressing Publish.

## Releasing one module

1. **If the pin moved**, land that first: update commit + SHA-256 together in
   `scripts/fetch-fonts.sh`, run it with `--force`, commit the new bytes, and let CI go green.
2. **Rehearse locally** (optional, free):
   ```
   ./gradlew :limn-fonts-noto-cjk:publishAllPublicationsToBuildDirRepository -PlimnFontsVersion=2.004.0
   ```
   With the signing key configured, every artifact under `build/repo` gets an `.asc` beside it.
3. **Tag, annotated, and push the tag:**
   ```
   git tag -a noto-cjk/v2.004.0 -m "limn-fonts-noto-cjk 2.004.0" && git push origin noto-cjk/v2.004.0
   ```
4. **Watch `publish`.** It re-verifies the pins, uploads the one module's signed bundle, and
   drafts the GitHub release.
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
