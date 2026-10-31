# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Rules
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter WindowManager Plus
-keep class com.pravera.flutter_windowmanager_plus.** { *; }

# MQTT & Network
-keep class org.eclipse.paho.** { *; }

# OpenFileX & Path Provider
-keep class com.crazecoder.openfile.** { *; }

# Google Play Core Deferred Components (R8 missing rules)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
