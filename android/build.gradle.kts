import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.compile.JavaCompile
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

subprojects {
    if (name == "uni_links") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                namespace = "com.keenora.uni_links"
            }
        }
    }

    if (name == "app_links") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                namespace = "com.llfbandit.app_links"
            }
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        doFirst {
            options.isWarnings = false
            if (!options.compilerArgs.contains("-nowarn")) {
                options.compilerArgs.add("-nowarn")
            }
            if (!options.compilerArgs.contains("-Xlint:-options")) {
                options.compilerArgs.add("-Xlint:-options")
            }
            if (!options.compilerArgs.contains("-Xlint:-deprecation")) {
                options.compilerArgs.add("-Xlint:-deprecation")
            }
            if (!options.compilerArgs.contains("-Xlint:-unchecked")) {
                options.compilerArgs.add("-Xlint:-unchecked")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
