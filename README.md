# limn-fonts

The [Limn toolkit](https://github.com/limn-toolkit/limn-toolkit)'s fallback faces, one Maven
artifact per font, **released apart** — so a face's version belongs to the face, and 16 MB of
pan-CJK that has not changed is never re-downloaded because something else did.

| Artifact | Covers | Size | Version tracks |
| --- | --- | --- | --- |
| `limn-fonts-roboto` | Latin, Greek, Cyrillic — the toolkit's default UI family, Regular/Bold/Italic/Bold-Italic | ~1.9 MB | its own `1.x` (mixed upstream builds; see the pins) |
| `limn-fonts-noto-cjk` | Han + Kana + Hangul (Noto Sans CJK Regular) | ~16 MB | upstream `Sans2.004` → `2.004.x` |
| `limn-fonts-noto-emoji` | Emoji, in colour (Noto Color Emoji) | ~10 MB | upstream `v2.051` → `2.051.x` |
| `limn-fonts-noto-scripts` | Arabic, Hebrew, Devanagari, Thai — Regular + Bold | ~1.1 MB | its own `1.x` (four families, one pinned upstream commit) |

`limn-fonts-roboto` is the one that is **not** an opt-in: it backs `Font.DEFAULT_FAMILY` and the
last-resort fallback, so the toolkit's LWJGL backend declares it as a real dependency and it
arrives with the backend. Roboto is under the Apache License 2.0; every other face is under the
SIL Open Font License 1.1. Each jar carries its font's licence text beside it, and each POM
names its own licence.

The repository's own few build files are Apache 2.0 (`LICENSE`).

## Using them

A jar here is resources and a licence — no code, no dependencies. Limn's `FontStore` finds the
faces on the classpath (under `limn/fonts/`) and degrades gracefully when a fallback is absent,
so an application opts in per fallback face and pays only for what it wants (Roboto needs no
line: it comes with `limn-backend-lwjgl`). Each jar names itself as a module (`limn.fonts.roboto`,
`limn.fonts.noto.cjk`, …), so on the module path the backend's `requires limn.fonts.roboto` loads
it, and loading one loads every other font jar on the path:

```kotlin
dependencies {
    runtimeOnly("io.github.limn-toolkit:limn-fonts-noto-cjk:2.004.0")
    runtimeOnly("io.github.limn-toolkit:limn-fonts-noto-emoji:2.051.0")
    runtimeOnly("io.github.limn-toolkit:limn-fonts-noto-scripts:1.0.0")
}
```

The toolkit's `limn-fonts-all` POM (published from the main repository, versioned with the
toolkit) names all of these at the versions that Limn release was tested with, for a build that
would rather not track three version numbers.

## Where the bytes come from

No font here was authored here. Each is pinned to an upstream commit and verified against a
SHA-256 in [`scripts/fetch-fonts.sh`](scripts/fetch-fonts.sh); the committed file is
byte-for-byte the pinned build, and CI re-verifies that on every push and before every release.
Moving a pin means changing the commit and the digest together — that diff is the review a
binary cannot have.

## Releasing

Per module, from a tag named `<module>/v<version>` — and nobody types or pushes one:
[`versions.properties`](versions.properties) is the single place a version is written, and on
every push to main the [`tag-releases`](.github/workflows/tag-releases.yml) workflow creates
whatever tags do not exist yet and starts their publishes. See [RELEASING.md](RELEASING.md).
