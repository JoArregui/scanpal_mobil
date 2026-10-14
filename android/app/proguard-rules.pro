# 1. Preservar modelos y entidades (Ruta específica de tu proyecto)
-keep class com.example.scanpalphone_app.domain.entities.** { *; }
-keep class com.example.scanpalphone_app.data.models.** { *; }
-keep class com.example.scanpalphone_app.models.** { *; }

# 2. Mantener nombres de campos y constructores (VITAL para Articulo.fromJson)
-keepclassmembers class com.example.scanpalphone_app.domain.entities.** {
    <fields>;
    <init>(...);
}

# 3. Evitar que ProGuard elimine métodos de decodificación JSON
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses

# 4. Soporte para Isolate y Sqflite
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# 5. Si usas HTTP (CMS sin S), esto protege la configuración de red
-keep class com.android.org.conscrypt.** { *; }