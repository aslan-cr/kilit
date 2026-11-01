pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "BeranMevaKilit"

// build.gradle.kts bulunan her klasör otomatik bir uygulama (modül) sayılır.
// Yeni uygulama eklemek için sadece yeni bir klasör eklemek yeter.
rootDir.listFiles()
    ?.filter { it.isDirectory && File(it, "build.gradle.kts").exists() }
    ?.sortedBy { it.name }
    ?.forEach { include(":${it.name}") }
