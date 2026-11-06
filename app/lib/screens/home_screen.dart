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
  List<dynamic> cidades = [];
  int indice = 0;
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

  void aviso(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  String msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> carregar() async {
    uid = await Api.usuarioId();
    if (uid == null) return abrirConfig();
    try {
      cidades = await Api.cidades(uid!);
      if (indice >= cidades.length) indice = 0;
      final d = await Api.previsao(uid!, cidadeId: cidades[indice]['id'] as int);
      if (!mounted) return;
      setState(() { dados = d; erro = null; });
      await Notificacoes.verificar(uid!);
    } catch (e) {
      if (mounted) setState(() => erro = 'Sem conexão com o servidor.');
    }
  }

  Future<void> abrirConfig() async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
    if (ok == true) carregar();
  }

  Future<void> trocar(int delta) async {
    if (cidades.length < 2) return;
    setState(() {
      indice = (indice + delta + cidades.length) % cidades.length;
      dados = null;
    });
    carregar();
  }

  Future<void> adicionarCidade() async {
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Adicionar cidade'),
          content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome da cidade')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Adicionar')),
          ],
        ));
    if (nome == null || nome.isEmpty || uid == null) return;
    try {
      await Api.adicionarCidade(uid!, nome);
      final lista = await Api.cidades(uid!);
      if (!mounted) return;
      setState(() {
        cidades = lista;
        indice = lista.length - 1; // vai direto para a cidade nova
        dados = null;
      });
      carregar();
    } catch (e) {
      if (mounted) aviso(msg(e));
    }
  }

  Future<void> removerCidadeAtual() async {
    if (cidades.length < 2) {
      aviso('Mantenha ao menos uma cidade.');
      return;
    }
    final c = cidades[indice];
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remover ${c['nome']}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remover')),
          ],
        ));
    if (ok != true || uid == null) return;
    try {
      await Api.removerCidade(uid!, c['id'] as int);
      if (!mounted) return;
      setState(() { indice = 0; dados = null; });
      carregar();
    } catch (e) {
      if (mounted) aviso(msg(e));
    }
  }

  Future<void> abrirAlertas() async {
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
              ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(erro!),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () {
                      setState(() => erro = null);
                      carregar();
                    },
                    child: const Text('Tentar de novo')),
              ]))
              : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: carregar, child: corpo(d)),
        ),
      ),
    );
  }

  Widget corpo(Map<String, dynamic> d) {
    final hoje = d['dias'][0];
    final varias = cidades.length > 1;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(icon: const Icon(Icons.settings), onPressed: abrirConfig),
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: abrirAlertas),
        IconButton(icon: const Icon(Icons.add_location_alt_outlined), onPressed: adicionarCidade),
      ]),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (varias)
          IconButton(
              icon: const Icon(Icons.chevron_left, size: 36),
              onPressed: () => trocar(-1)),
        Flexible(
          child: GestureDetector(
            onLongPress: removerCidadeAtual, // segurar o nome remove a cidade
            child: Text(d['cidade'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34)),
          ),
        ),
        if (varias)
          IconButton(
              icon: const Icon(Icons.chevron_right, size: 36),
              onPressed: () => trocar(1)),
      ]),
      if (varias)
        Center(
            child: Text('${indice + 1} / ${cidades.length}',
                style: const TextStyle(fontSize: 12))),
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