import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

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
    // Inyectar namespace para librerías legacy que no lo tengan especificado
    // Usamos esta lógica directamente en el bloque subprojects para evitar afterEvaluate issues
    val androidExt = project.extensions.findByName("android")
    if (androidExt is com.android.build.gradle.BaseExtension) {
        if (androidExt.namespace == null) {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val manifestXml = groovy.xml.XmlParser().parse(manifestFile)
                val packageName = manifestXml.attribute("package")?.toString()
                if (packageName != null) {
                    androidExt.namespace = packageName
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
