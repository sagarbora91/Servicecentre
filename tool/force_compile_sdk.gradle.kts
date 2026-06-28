// Appended to the (ephemeral, `flutter create`-generated) android/build.gradle.kts
// by the APK workflow. Some plugins (e.g. flutter_plugin_android_lifecycle,
// pulled transitively by file_picker / image_picker) now require consumers to
// compile against android-36, but the plugin modules themselves are still
// generated against compileSdk 34, failing :<plugin>:checkDebugAarMetadata.
//
// Force compileSdk 36 on every Android subproject. Reflection is used so this
// root build script does not need the Android Gradle Plugin on its classpath.
subprojects {
    fun applyCompileSdk() {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Integer.TYPE
            }
            setter?.invoke(androidExt, 36)
        }
    }
    // The Flutter-generated root script does `evaluationDependsOn(":app")`,
    // which eagerly evaluates :app before this block runs — calling
    // afterEvaluate on an already-evaluated project throws. :app's compileSdk is
    // already set via sed, so configure it directly and only defer the plugin
    // modules (not yet evaluated) to afterEvaluate.
    if (state.executed) {
        applyCompileSdk()
    } else {
        afterEvaluate { applyCompileSdk() }
    }
}
