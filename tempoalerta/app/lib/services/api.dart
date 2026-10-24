import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Emulador Android -> 10.0.2.2 ; celular físico -> IP do PC (ex: 192.168.0.10)
const String baseUrl = 'http://10.0.2.2:8000';

class Api {
  static Future<int?> usuarioId() async =>
      (await SharedPreferences.getInstance()).getInt('uid');

  static Future<void> cadastrar({
    required String nome, required String email, required String cidade,
    required String horario, required bool chuva, required bool geada,
  }) async {
    final r = await http.post(Uri.parse('$baseUrl/cadastro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome, 'email': email, 'cidade': cidade, 'horario': horario,
          'alerta_chuva': chuva, 'alerta_geada': geada,
        }));
    if (r.statusCode != 200) {
      throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Erro');
    }
    final uid = jsonDecode(r.body)['usuario_id'] as int;
    (await SharedPreferences.getInstance()).setInt('uid', uid);
  }

  static Future<Map<String, dynamic>> previsao(int uid) async {
    final r = await http.get(Uri.parse('$baseUrl/previsao/$uid'));
    if (r.statusCode != 200) throw Exception('Falha ao carregar previsão');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<List<dynamic>> alertas(int uid) async {
    final r = await http.get(Uri.parse('$baseUrl/alertas/$uid'));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<void> testar(int uid) =>
      http.post(Uri.parse('$baseUrl/testar/$uid'));
}
