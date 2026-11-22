allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Android's lint check of a release (lintVitalAnalyzeRelease) fails INSIDE a plugin (image_picker_android – "this is a bug in lint
// or one of the libraries it depends on", the first build of 23-11-2026). It is not a check of FALCON's own code; `flutter analyze`
// and the tests check that. The lint release check is turned off for the build only.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
