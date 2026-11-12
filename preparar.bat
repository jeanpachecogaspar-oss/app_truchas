@echo off
REM SIPPT - deja el proyecto listo y lo conecta con TU proyecto de Firebase.
REM Ejecutalo en la carpeta del proyecto:  .\preparar.bat

echo.
echo [1/4] Descargando paquetes de Flutter...
call flutter pub get || goto :error

echo.
echo [2/4] Instalando Firebase CLI (requiere Node.js)...
call firebase --version >nul 2>&1 || call npm install -g firebase-tools || goto :error

echo.
echo [3/4] Instalando FlutterFire CLI...
call dart pub global activate flutterfire_cli || goto :error

echo.
echo [4/4] Inicia sesion con tu cuenta de Google y elige el proyecto de Firebase...
call firebase login
call "%LOCALAPPDATA%\Pub\Cache\bin\flutterfire.bat" configure --platforms=android --android-package-name=pe.edu.continental.sippt_movil || goto :error

echo.
echo Listo. Ahora ejecuta:  flutter run
goto :eof

:error
echo.
echo Algo fallo en el paso anterior. Copia el mensaje y revisalo en README.md.
exit /b 1
