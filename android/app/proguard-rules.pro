# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Fix for missing classes in auto-value / javapoet / javax.lang.model
# These are annotation processing dependencies that sometimes leak into the release build classpath analysis
-dontwarn javax.lang.model.**
-dontwarn com.squareup.javapoet.**
-dontwarn com.google.auto.value.**
-dontwarn autovalue.shaded.**

# We don't need these at runtime generally, but sometimes R8 complains if they are missing
-keep class javax.lang.model.** { *; }

# Fix for Flutter deferred components / Play Core missing classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
