rootProject.name = "limn-fonts"

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenCentral()
    }
}

// One module per fallback font, because they release APART — that is this repository's whole
// reason to exist. A face here changes only when its upstream pin moves, so its artifact keeps
// one version for as long as the bytes do, and an application's cache keeps the 16 MB pan-CJK
// jar across every Limn release that names the same font version. A single module would tie the
// three back together: bumping the emoji pin would re-version 27 MB of faces that did not change.
//
// No module here depends on anything, including limn-toolkit: a font jar is resources and a
// licence, and the toolkit's FontStore finds the faces by classpath path (limn/fonts/<file>).
// The aggregator POM that names these at pinned versions lives in the MAIN repository
// (limn-fonts-all), versioned with the toolkit, because "which font versions this Limn was
// tested with" is a fact about the toolkit, not about the fonts.
include(
    "limn-fonts-noto-cjk",
    "limn-fonts-noto-emoji",
    "limn-fonts-noto-scripts",
)
