# SIPPT Móvil — Flutter + Firebase

App del **Sistema Inteligente para la Optimización de la Producción Piscícola
de Trucha**. Ya no necesita Docker ni la API Laravel: el inicio de sesión va por
**Firebase Authentication** y los datos están en **Cloud Firestore**, en tiempo
real (cuando alguien cierra una alerta, los demás celulares lo ven al instante).

## Qué trae

- **Entrada animada**: una trucha arcoíris salta, cae al agua, salpica y se hunde mientras aparece la marca. Si tocas la pantalla, se salta la animación.
- **Acceso** sobre un fondo de agua animado (montañas, burbujas, truchas nadando). Permite iniciar sesión, crear una cuenta eligiendo el rol y recuperar la contraseña.
- **Alertas (HU-04 y HU-05)**: las abiertas aparecen primero las críticas. Avisa con vibración cuando llega una nueva. El formulario de atención sugiere acciones según el parámetro. Tiene un **historial** de atenciones que muestra quién atendió y cuándo.
- **Estanques (HU-03)**: semáforo con forma, color y palabra, medidor de rango, marca de «sin señal» y antigüedad de cada lectura. Al tocar un estanque se abre la tendencia de 24 h con su banda aceptable, el mínimo, el promedio y el máximo, y las últimas lecturas.
- **Nuevo estanque (HU-01)**, solo para el técnico: umbrales con valores sugeridos para trucha.
- **Simulador de sensores (HU-02)**, solo para el técnico: envía lecturas como lo harían los nodos IoT. Se puede programar cada 30 s y elegir la probabilidad de anomalías. Las alertas se generan de verdad.
- **Datos de demostración**: con un toque se crean 4 estanques con 24 h de historia (uno normal, uno en advertencia, uno crítico y uno sin señal).
- **Reglas de seguridad por rol** en `firestore.rules`.
- Ícono de la app con la trucha y tema claro y oscuro.

## Puesta en marcha (una sola vez)

### 1. Crear el proyecto en Firebase

1. Entra a <https://console.firebase.google.com> y crea un proyecto (por ejemplo `sippt-trucha`). Puedes desactivar Google Analytics.
2. **Authentication** → *Comenzar* → *Correo electrónico/contraseña* → **Habilitar** → Guardar.
3. **Firestore Database** → *Crear base de datos* → ubicación `southamerica-east1` (São Paulo) → *modo de producción*.
4. En Firestore, pestaña **Reglas**: borra lo que haya, pega todo el contenido de `firestore.rules` y pulsa **Publicar**.

### 2. Conectar la app con tu proyecto

Necesitas tener instalado [Node.js](https://nodejs.org). Luego, en la terminal de VS Code, dentro de esta carpeta:

```
.\preparar.bat
```

El script descarga los paquetes, instala las herramientas de Firebase, te pide
iniciar sesión con tu cuenta de Google y te deja **elegir el proyecto** que
creaste. Al terminar genera `lib/firebase_options.dart` y
`android/app/google-services.json`.

### 3. Ejecutar

```
flutter run
```

### 4. Primer uso

1. Toca **Crear cuenta**, escribe tu nombre y elige el rol **Técnico acuícola**.
2. En **Estanques** toca **Cargar datos de demostración**.
3. Para probar los otros roles, cierra sesión (toca tus iniciales arriba a la derecha) y crea otra cuenta como **Operador** o **Veterinario**.
4. Con el técnico, abre **Simulador de sensores** desde el mismo menú y activa el envío automático: verás llegar alertas en vivo.

## Roles

| Rol | Ve | Puede |
|---|---|---|
| Operador | Alertas primero | Registrar la atención de alertas |
| Técnico | Alertas, estanques y Nuevo | Todo: crear estanques, simular sensores, atender alertas |
| Veterinario | Estanques primero | Solo consultar |

El rol se elige al crear la cuenta. Para cambiarlo después, edita el campo
`rol` del usuario en la colección `usuarios` desde la consola de Firestore.

> En un sistema real, el rol lo asignaría un administrador y no se elegiría al
> registrarse. Para la demostración académica, así es más práctico.

## Estructura de datos (Firestore)

```
usuarios/{uid}                      nombre, email, rol
estanques/{código}                  volumen_m3, biomasa_kg, etapa,
                                    umbrales {od_mgl|temp_c|ph: {min, max, margen}},
                                    ultimas  {parámetro: {valor, medido_en}},
                                    alertas_abiertas {parámetro: id de alerta}
estanques/{código}/series/{parámetro}/lecturas/{id}   valor, medido_en
alertas/{id}                        estanque, parámetro, severidad, estado,
                                    valor_detectado, umbral_violado, ultimo_valor,
                                    generada_en, atencion {accion, observacion, usuario, registrada_en}
```

Las reglas del backend Laravel se conservan:
- El **margen crítico** se cuenta por fuera del rango: la alerta es crítica bajo `mín − margen` o sobre `máx + margen`.
- **No se duplican alertas**: si ya hay una abierta para ese estanque y parámetro, se actualiza su último valor y se agrava si pasa a crítica.
- Una alerta **no se cierra sola** al volver al rango: se cierra registrando la intervención.
- Una lectura fuera del **rango físico** del sensor se descarta, porque indica un instrumento averiado.
- Toda escritura guarda **quién la hizo** (RNF-04).

## Estructura del código

```
lib/
  main.dart                 arranque: animación → acceso → tablero
  firebase_options.dart     lo genera «flutterfire configure»
  api.dart                  Firebase Auth + Firestore (transacciones, demo, simulador)
  evaluacion.dart           reglas puras de umbrales y semáforo (con pruebas)
  modelos.dart              datos de Firestore
  escucha_alertas.dart      detecta alertas nuevas para avisar
  formato.dart  tema.dart   presentación y paleta
  pantallas/  bienvenida · acceso · tablero · detalle_estanque · alta_estanque · simulador
  widgets/    trucha (vectorial) · agua (escena animada) · tarjetas · gráfico · distintivo · resumen
firestore.rules             permisos por rol
```

## Problemas frecuentes

| Mensaje | Solución |
|---|---|
| «Falta conectar Firebase» | No se ejecutó `preparar.bat` (o `flutterfire configure`) |
| «El acceso con correo no está activado» | Paso 1.2: habilita Correo/contraseña en Authentication |
| «La base de datos Firestore no existe» | Paso 1.3: crea la base de datos |
| «Tu rol no tiene permiso» | Faltan las reglas (paso 1.4), o tu rol no permite esa acción |
| `flutterfire` no se reconoce | Cierra y vuelve a abrir VS Code, y ejecuta otra vez `.\preparar.bat` |

## Generar el APK

```
flutter build apk --release
```
Queda en `build/app/outputs/flutter-apk/app-release.apk`.
