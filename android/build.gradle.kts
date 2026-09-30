allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Must be registered before evaluationDependsOn below starts evaluating projects.
// screen_brightness_android 1.0.1 sets compileSdk 31, but its AndroidX
// dependencies need 34+. AGP 9 fails the build on that mismatch for libraries.
// Remove this when screen_brightness moves to 2.x (its API changed, so that is a code change).
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
