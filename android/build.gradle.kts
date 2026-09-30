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

// ---------------------------------------------------------------------------
// 1) 统一所有插件子工程的 compileSdk
//    有些插件在自己 android/build.gradle 里写死了较低的 compileSdk（例如
//    file_picker 8.3.7 是 34），而它依赖的 flutter_plugin_android_lifecycle
//    要求 compileSdk >= 36，不统一就会在 :file_picker:checkDebugAarMetadata 直接失败。
// 2) 原生库不剥离调试符号（在 app 的 packaging.keepDebugSymbols 里设置）
//    本机没装 NDK（本项目插件的 .so 都是预编译好的），strip 会去调
//    <ndk>/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip 而失败；
//    剥离调试符号只影响产物体积，不影响功能。
// 说明：compileSdk 是 android 扩展上的属性，不是 Project 的属性，所以这里用反射
// 直接调扩展的 setter；另外上面的 evaluationDependsOn(":app") 可能已经把 :app
// 评估完了，因此要先看 state.executed，否则 afterEvaluate 会报错。
// ---------------------------------------------------------------------------
subprojects {
    fun applyUnifiedCompileSdk() {
        val androidExtension = extensions.findByName("android")
        if (androidExtension == null) return
        val primitive = Int::class.javaPrimitiveType!!
        val attempts = listOf(
            Pair("setCompileSdk", Integer::class.java),
            Pair("setCompileSdk", primitive),
            Pair("compileSdkVersion", primitive),
            Pair("compileSdkVersion", Integer::class.java)
        )
        for ((methodName, argType) in attempts) {
            try {
                androidExtension.javaClass.getMethod(methodName, argType).invoke(androidExtension, 36)
                logger.lifecycle("[compileSdk 统一] " + name + " 用 " + methodName + " 设为 36")
                return
            } catch (ignored: Throwable) {
                // 换下一种签名再试
            }
        }
        logger.warn("[compileSdk 统一] " + name + " 未能设置 compileSdk（不影响 app 自身）")
    }
    if (state.executed) {
        applyUnifiedCompileSdk()
    } else {
        afterEvaluate { applyUnifiedCompileSdk() }
    }
}