import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/notificacoes.dart';
import '../theme/periodo.dart';
import 'config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? dados;
  String? erro;
  int? uid;
  Periodo periodo = Periodo.agora();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    Notificacoes.iniciar();
    carregar();
    // reavalia o tema e confere novos alertas a cada minuto
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => periodo = Periodo.agora());
      if (uid != null) Notificacoes.verificar(uid!);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> carregar() async {
    uid = await Api.usuarioId();
    if (uid == null) return abrirConfig();
    try {
      final d = await Api.previsao(uid!);
      setState(() { dados = d; erro = null; });
      await Notificacoes.verificar(uid!);
    } catch (e) {
      setState(() => erro = 'Sem conexão com o servidor.');
    }
  }

  Future<void> abrirConfig() async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
    if (ok == true) carregar();
  }

  Future<void> abrirAlertas() async {
    await Api.testar(uid!); // gera um envio de teste
    await Notificacoes.verificar(uid!);
    final lista = await Api.alertas(uid!);
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        builder: (_) => ListView(children: [
          for (final a in lista)
            ListTile(
                leading: Icon(a['tipo'] == 'geada' ? Icons.ac_unit
                    : a['tipo'] == 'chuva' ? Icons.thunderstorm : Icons.wb_sunny),
                title: Text(a['mensagem']),
                subtitle: Text(a['enviado_em'])),
        ]));
  }

  static IconData icone(int c) {
    if (c == 0) return Icons.wb_sunny;
    if (c <= 2) return Icons.wb_cloudy;
    if (c == 3) return Icons.cloud;
    if (c <= 48) return Icons.foggy;
    if (c <= 67 || (c >= 80 && c <= 82)) return Icons.grain;
    if (c <= 77) return Icons.ac_unit;
    return Icons.thunderstorm;
  }

  Color corIcone(int c) => c <= 2 ? Colors.amber : Colors.white;

  String umidade(num u) => u < 40 ? 'Baixa umidade' : u < 70 ? 'Média umidade' : 'Alta umidade';

  @override
  Widget build(BuildContext context) {
    final d = dados;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: periodo.gradiente)),
        child: SafeArea(
          child: erro != null
              ? Center(child: Text(erro!))
              : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: carregar, child: corpo(d)),
        ),
      ),
    );
  }

  Widget corpo(Map<String, dynamic> d) {
    final hoje = d['dias'][0];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: abrirAlertas),
        IconButton(icon: const Icon(Icons.add), onPressed: abrirConfig),
      ]),
      const SizedBox(height: 40),
      Center(child: Text(d['cidade'], style: const TextStyle(fontSize: 38))),
      Center(child: Text(umidade(d['atual']['umidade']), style: const TextStyle(fontSize: 20))),
      Center(child: Text('${d['atual']['temp'].round()}° C',
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w200))),
      Center(child: Text('Máx.: ${hoje['max'].round()}° Mín.: ${hoje['min'].round()}°')),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: periodo.card, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final h in d['horas'])
            Column(children: [
              Text(h['hora'], style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Icon(icone(h['codigo']), color: corIcone(h['codigo'])),
              const SizedBox(height: 6),
              Text('${h['temp'].round()}°'),
            ]),
        ]),
      ),
      const Divider(height: 32),
      for (final dia in d['dias'].skip(1))
        ListTile(
          dense: true,
          title: Text(dia['dia_semana']),
          leading: Icon(icone(dia['codigo']), color: corIcone(dia['codigo'])),
          trailing: Text('${dia['min'].round()}° / ${dia['max'].round()}°  •  ${dia['chuva_prob']}%'),
        ),
    ]);
  }
}