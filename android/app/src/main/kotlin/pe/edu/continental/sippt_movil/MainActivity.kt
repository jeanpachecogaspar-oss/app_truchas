package pe.edu.continental.sippt_movil

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Notificaciones de alertas de SIPPT sin paquetes externos.
 *
 * Dart llama por el canal "sippt/notificaciones":
 *   - pedirPermiso: en Android 13+ pide POST_NOTIFICATIONS.
 *   - mostrar {id, titulo, texto, critica}: publica la notificación.
 */
class MainActivity : FlutterActivity() {
    private val nombreCanal = "sippt/notificaciones"
    private val idCanalAlertas = "alertas_sippt"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        crearCanalDeAlertas()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nombreCanal).setMethodCallHandler { llamada, resultado ->
            when (llamada.method) {
                "pedirPermiso" -> {
                    pedirPermiso()
                    resultado.success(true)
                }
                "mostrar" -> {
                    val id = llamada.argument<Int>("id") ?: 0
                    val titulo = llamada.argument<String>("titulo") ?: "SIPPT"
                    val texto = llamada.argument<String>("texto") ?: ""
                    val critica = llamada.argument<Boolean>("critica") ?: false
                    resultado.success(mostrar(id, titulo, texto, critica))
                }
                else -> resultado.notImplemented()
            }
        }
    }

    private fun crearCanalDeAlertas() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                idCanalAlertas,
                "Alertas de estanques",
                NotificationManager.IMPORTANCE_HIGH,
            )
            canal.description = "Avisos cuando el pH, el oxígeno o la temperatura salen de rango"
            canal.enableVibration(true)
            getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
        }
    }

    private fun tienePermiso(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun pedirPermiso() {
        if (!tienePermiso()) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7001)
        }
    }

    private fun mostrar(id: Int, titulo: String, texto: String, critica: Boolean): Boolean {
        if (!tienePermiso()) return false

        val abrirApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notificacion = constructor()
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setColor(if (critica) 0xFFD03B3B.toInt() else 0xFFB7791F.toInt())
            .setCategory(Notification.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(abrirApp)
            .build()

        getSystemService(NotificationManager::class.java).notify(id, notificacion)
        return true
    }

    @Suppress("DEPRECATION")
    private fun constructor(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, idCanalAlertas)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }
}
