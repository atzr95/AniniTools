# Flutter's Gradle plugin adds this file to the release build automatically.

# Firebase builds its components by class name (listed in the manifest) with a
# no-argument constructor. R8 in AGP 9 no longer keeps that constructor on its own,
# so Crashlytics was left out at startup ("FirebaseCrashlytics component is not present").
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
