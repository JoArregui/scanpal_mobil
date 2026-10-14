#!/bin/bash

echo "🧹 Limpiando proyecto..."
flutter clean
rm -rf build/

echo "📦 Obteniendo dependencias..."
flutter pub get

echo "🔨 Compilando APK Release..."
flutter build apk --release --verbose

echo "✅ APK generado en: build/app/outputs/flutter-apk/app-release.apk"

echo "📱 ¿Instalar en dispositivo conectado? (y/n)"
read -r response
if [[ "$response" == "y" ]]; then
    flutter install --release
    
    echo "📊 Iniciando logs..."
    adb logcat -c
    adb logcat | grep -E "flutter|REMOTE_DS|LOCAL_DS|DB_HELPER|REPO"
fi