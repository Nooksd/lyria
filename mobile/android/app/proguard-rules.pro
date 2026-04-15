# ExoPlayer / just_audio
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
