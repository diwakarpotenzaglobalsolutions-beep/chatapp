import com.android.build.gradle.LibraryExtension
import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.zego.im/maven") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    afterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.apply {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}