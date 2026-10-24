import 'package:flutter/material.dart';
import '../services/api.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final nome = TextEditingController();
  final email = TextEditingController();
  final cidade = TextEditingController();
  TimeOfDay hora = const TimeOfDay(hour: 7, minute: 0);
  bool chuva = true, geada = true, salvando = false;

  String get horario =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  Future<void> salvar() async {
    setState(() => salvando = true);
    try {
      await Api.cadastrar(nome: nome.text, email: email.text, cidade: cidade.text,
          horario: horario, chuva: chuva, geada: geada);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => salvando = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Configurar alertas')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(controller: cidade, decoration: const InputDecoration(labelText: 'Cidade')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Horário da previsão diária'),
            trailing: Text(horario, style: const TextStyle(fontSize: 20)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: hora);
              if (t != null) setState(() => hora = t);
            },
          ),
          SwitchListTile(title: const Text('Alerta de chuva forte'),
              value: chuva, onChanged: (v) => setState(() => chuva = v)),
          SwitchListTile(title: const Text('Alerta de geada'),
              value: geada, onChanged: (v) => setState(() => geada = v)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: salvando ? null : salvar,
              child: Text(salvando ? 'Salvando...' : 'Salvar')),
        ]),
      );
}
