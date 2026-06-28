// Appended to the (ephemeral, `flutter create`-generated) android/build.gradle.kts
// by the APK workflow. Some plugins (e.g. flutter_plugin_android_lifecycle,
// pulled transitively by file_picker / image_picker) now require consumers to
// compile against android-36, but the plugin modules themselves are still
// generated against compileSdk 34, failing :<plugin>:checkDebugAarMetadata.
//
// Force compileSdk 36 on every Android subproject. Reflection is used so this
// root build script does not need the Android Gradle Plugin on its classpath.
subprojects {
    afterEvaluate {
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
}
