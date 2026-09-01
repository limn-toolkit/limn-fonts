// limn-fonts: the Limn toolkit's fallback faces, one Maven artifact per font, released APART.
//
// This repository exists for one property the main repository cannot have: a font's version
// belongs to the FONT, not to the toolkit. The pan-CJK face is 16 MB that changes only when its
// upstream pin moves, which is close to never; published from limn-toolkit it was re-versioned
// and re-uploaded with every toolkit release, and every consumer re-downloaded bytes that had
// not changed. Here each face keeps its own version for as long as its bytes do.
//
// NOTHING here is compiled. A module is resources (the font, its licence) and a POM. The
// toolkit's FontStore loads the faces by classpath path — limn/fonts/<file> — and degrades
// gracefully when a jar is absent, so an application opts in per face:
//
//   limn-fonts-noto-cjk      Han + Kana + Hangul (Noto Sans CJK, ~16 MB)
//   limn-fonts-noto-emoji    colour emoji (Noto Color Emoji, ~10 MB)
//   limn-fonts-noto-scripts  Arabic, Hebrew, Devanagari, Thai, Regular + Bold (~1.1 MB)
//
// RELEASES ARE PER MODULE, from a tag named `<module>/v<version>` with the `limn-fonts-` prefix
// dropped: `noto-cjk/v2.004.0` publishes limn-fonts-noto-cjk 2.004.0 and touches nothing else.
// See RELEASING.md. The version reaches Gradle as -PlimnFontsVersion, and otherwise every module
// reads the -SNAPSHOT of its own default below, which is what publishToMavenLocal wants.

import com.vanniktech.maven.publish.MavenPublishBaseExtension

plugins {
    base
    alias(libs.plugins.central.publish) apply false
}

// Per-module: the version a dev build carries, and the one line of the POM that is not shared.
//
// The defaults track the upstream release each pin in scripts/fetch-fonts.sh points at
// (CJK tag Sans2.004, emoji tag v2.051), written with a third component so a rebuild of an
// unchanged upstream has a number to spend: repackaging Sans2.004 twice is 2.004.0 and 2.004.1.
// noto-scripts aggregates four families pinned to one notofonts.github.io commit, which has no
// single upstream number, so it versions itself plainly from 1.0.0.
val fontModules = mapOf(
    "limn-fonts-noto-cjk" to Pair(
        "2.004.0",
        "Noto Sans CJK Regular (pan-CJK: Han, Kana, Hangul) as a Limn fallback face. " +
                "Resources only; the toolkit's FontStore picks it up from the classpath."),
    "limn-fonts-noto-emoji" to Pair(
        "2.051.0",
        "Noto Color Emoji (CBDT colour bitmaps) as a Limn fallback face. " +
                "Resources only; the toolkit's FontStore picks it up from the classpath."),
    "limn-fonts-noto-scripts" to Pair(
        "1.0.0",
        "Noto Sans Arabic, Hebrew, Devanagari and Thai, Regular and Bold, as Limn fallback " +
                "faces for the complex scripts. Resources only; the toolkit's FontStore picks " +
                "them up from the classpath."),
)

allprojects {
    group = "io.github.limn-toolkit"
}

// The committed faces, checked against the pins before anything else runs. A font is a binary
// nobody reviews in a diff, so the digest list in scripts/fetch-fonts.sh is the review: this
// task fails if a committed face is missing or is not byte-for-byte the build its pin names.
val verifyFonts = tasks.register<Exec>("verifyFonts") {
    description = "Fails if any committed font differs from the pinned upstream build."
    group = "verification"
    commandLine("bash", "scripts/fetch-fonts.sh", "--check")
}

subprojects {
    val (defaultVersion, moduleDescription) = fontModules[name]
        ?: throw GradleException("module '$name' is not in fontModules; add it beside the others")

    version = (findProperty("limnFontsVersion") as String?) ?: "$defaultVersion-SNAPSHOT"

    apply(plugin = "java-library")
    apply(plugin = "com.vanniktech.maven.publish")

    extensions.configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
        withSourcesJar()
    }

    // The faces are vendored binaries, and a sources jar is not where a binary belongs: it
    // answers "what was this built from", and the licence text is the whole part of this module
    // that has an answer. Same trade, same reasoning, as the toolkit's backend made when the
    // faces lived there.
    tasks.named<Jar>("sourcesJar") {
        exclude("limn/fonts/*.ttf", "limn/fonts/*.otf")
    }

    tasks.named("check") {
        dependsOn(verifyFonts)
    }

    extensions.configure<MavenPublishBaseExtension> {
        // Uploads and stops: the deployment sits staged on the Central Portal until somebody
        // presses Publish, which is the last moment a release can still be dropped.
        publishToMavenCentral()

        // Conditional for the same reason as in limn-toolkit: publishToMavenLocal must work on
        // a machine with no key, and the guard at the bottom of this file is the other half —
        // a RELEASE without a key must fail here, not on the Portal after the upload.
        if (providers.gradleProperty("signingInMemoryKey").isPresent ||
                providers.gradleProperty("signing.keyId").isPresent) {
            signAllPublications()
        }

        pom {
            name.set(this@subprojects.name)
            description.set(moduleDescription)
            url.set("https://github.com/limn-toolkit/limn-fonts")
            scm {
                url.set("https://github.com/limn-toolkit/limn-fonts")
                connection.set("scm:git:https://github.com/limn-toolkit/limn-fonts.git")
                developerConnection.set("scm:git:ssh://git@github.com/limn-toolkit/limn-fonts.git")
            }
            // The licence of the CONTENT, not of this build script: everything inside the jar is
            // a font and its licence text, and every face here is under the SIL OFL 1.1. The
            // repository's own few build files are Apache 2.0 (see LICENSE), and none of them
            // is in any artifact.
            licenses {
                license {
                    name.set("SIL Open Font License, Version 1.1")
                    url.set("https://openfontlicense.org/open-font-license-official-text/")
                }
            }
            developers {
                developer {
                    id.set("dyorgio")
                    name.set("Dyorgio Nascimento")
                    url.set("https://github.com/dyorgio")
                }
            }
        }
    }

    // A plain file repository under build/repo, for looking at what would ship without sending
    // it anywhere. RELEASING.md's rehearsal step publishes here and checks for the .asc files.
    plugins.withId("maven-publish") {
        extensions.configure<PublishingExtension> {
            repositories {
                maven {
                    name = "buildDir"
                    url = uri(rootProject.layout.buildDirectory.dir("repo"))
                }
            }
        }
    }
}

// A release that Central would reject on validation (unsigned), caught before anything leaves
// the machine. On the task graph rather than on the tasks, because publishToMavenCentral
// aggregates: a doFirst on it runs after the upload it depends on already happened.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any {
        it.name == "publishToMavenCentral" || it.name == "publishAndReleaseToMavenCentral" ||
                it.name.startsWith("publishAllPublicationsToMavenCentral")
    }
    if (!releasing) return@whenReady

    // The root project carries no version here (each module defaults its own), so what decides
    // release-versus-snapshot is the property a release passes: absent, every module is at its
    // -SNAPSHOT default and the Portal routes the upload to the snapshot repository.
    val requested = providers.gradleProperty("limnFontsVersion").orNull
    if (requested == null || requested.endsWith("-SNAPSHOT")) {
        logger.lifecycle(
            "publishing a -SNAPSHOT to Central's snapshot repository. This is not a release: " +
                    "tag <module>/v<version> for one (see RELEASING.md)."
        )
        return@whenReady
    }

    // One release, one module. -PlimnFontsVersion applies to EVERY module in the invocation, so
    // a bare `./gradlew publishToMavenCentral -PlimnFontsVersion=2.004.0` would stamp the emoji
    // and scripts faces with the CJK face's number and upload all three. The workflow always
    // targets one module's task; this makes a hand-typed release do the same or say why not.
    val releasingModules = allTasks
        .filter { it.name == "publishToMavenCentral" || it.name == "publishAndReleaseToMavenCentral" }
        .map { it.project.name }
        .distinct()
    if (releasingModules.size > 1) {
        throw GradleException(
            "refusing to release ${releasingModules.size} modules under one version: " +
                    "$requested belongs to ONE face. Target it alone, e.g. " +
                    "./gradlew :${releasingModules.first()}:publishToMavenCentral " +
                    "-PlimnFontsVersion=$requested (see RELEASING.md)."
        )
    }

    if (!providers.gradleProperty("signingInMemoryKey").isPresent &&
            !providers.gradleProperty("signing.keyId").isPresent) {
        throw GradleException(
            "refusing to publish to Maven Central unsigned: no signing key is configured, and " +
                    "Central requires a signature on every artifact of a release. Set " +
                    "signingInMemoryKey and signingInMemoryKeyPassword (the publish workflow " +
                    "passes them as ORG_GRADLE_PROJECT_ environment variables)."
        )
    }
}
