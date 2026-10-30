import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class Notificacoes {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> iniciar() async {
    await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Mostra na barra os alertas que ainda não foram notificados.
  static Future<void> verificar(int uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = await Api.alertas(uid); // mais novo primeiro
      final ultimo = prefs.getInt('ultimo_alerta');
      final maior = lista.isEmpty ? 0 : lista.first['id'] as int;
      if (ultimo != null) {
        for (final a in lista.reversed.where((a) => (a['id'] as int) > ultimo)) {
          await _plugin.show(
              a['id'] as int, 'TempoAlerta', a['mensagem'],
              const NotificationDetails(
                  android: AndroidNotificationDetails(
                      'tempoalerta', 'Alertas do tempo',
                      importance: Importance.high, priority: Priority.high)));
        }
      }
      await prefs.setInt('ultimo_alerta', maior);
    } catch (_) {}
  }
}