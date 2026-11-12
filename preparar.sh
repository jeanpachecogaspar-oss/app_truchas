#!/usr/bin/env sh
# SIPPT - deja el proyecto listo y lo conecta con TU proyecto de Firebase.
set -e
flutter pub get
command -v firebase >/dev/null 2>&1 || npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
"$HOME/.pub-cache/bin/flutterfire" configure --platforms=android,ios --android-package-name=pe.edu.continental.sippt_movil
echo "Listo. Ahora ejecuta:  flutter run"
