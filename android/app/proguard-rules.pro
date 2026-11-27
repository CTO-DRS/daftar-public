# ML Kit text recognition: optional script modules we do not bundle (Latin only).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.yalantis.ucrop.**

# ML Kit's native OCR pipeline looks up Java classes/methods by name over JNI,
# and its components are discovered by reflection. R8 renaming/stripping them
# makes the scan fail in release builds with a NullPointerException.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keepclasseswithmembernames class * { native <methods>; }

# flutter_local_notifications serialises scheduled notifications with Gson (reflection).
-keep class com.dexterous.** { *; }
