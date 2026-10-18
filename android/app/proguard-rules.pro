# R8 rules for the release build (minifyEnabled + shrinkResources in
# app/build.gradle). Flutter's Gradle plugin adds its own
# flutter_proguard_rules.pro, and the Firebase and Google Play services
# libraries ship consumer rules; what is here is what they do not cover.

# --- Razorpay (razorpay_flutter README, "Proguard rules") ------------------
# The checkout calls back into onPaymentSuccess/onPaymentError by
# reflection; stripped or inlined, a paid order never reaches the app.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# --- Flutter ---------------------------------------------------------------
# The embedding references Play Core for deferred components, which this
# app does not use; without these R8 fails on the missing classes.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Firebase --------------------------------------------------------------
# Readable Crashlytics stack traces: keep file names, line numbers and
# exception class names.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- flutter_local_notifications (its README: Gson rules) -----------------
# Scheduled notifications are stored as JSON through Gson, which reads
# fields by reflection.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
