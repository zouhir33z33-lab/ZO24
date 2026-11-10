#!/usr/bin/env bash
# Applique la configuration Android après `flutter create` (permissions, nom).
set -e
M=android/app/src/main/AndroidManifest.xml
if ! grep -q "MANAGE_EXTERNAL_STORAGE" "$M"; then
  sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>\n    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>\n    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>\n    <application|' "$M"
fi
sed -i 's|android:label="[^"]*"|android:label="EPS Assistant"|' "$M"

# Canal natif de luminosité (bouton « شمس » du mode terrain)
KDIR=android/app/src/main/kotlin/dz/eps/assistant/eps_assistant
mkdir -p "$KDIR"
cp scripts/MainActivity.kt "$KDIR/MainActivity.kt"
