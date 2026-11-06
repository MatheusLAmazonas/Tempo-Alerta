import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/home_screen.dart';
import 'services/api.dart';
import 'services/notificacoes.dart';

/// Roda em segundo plano (a cada ~15 min), mesmo com o app fechado.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final uid = await Api.usuarioId();
      if (uid != null) {
        await Notificacoes.iniciar(pedirPermissao: false);
        await Notificacoes.verificar(uid);
      }
    } catch (_) {}
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'tempoalerta-alertas',
    'verificarAlertas',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  runApp(const TempoAlertaApp());
}

class TempoAlertaApp extends StatelessWidget {
  const TempoAlertaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TempoAlerta',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const HomeScreen(),
  );
}