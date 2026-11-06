import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Emulador Android -> 10.0.2.2 ; celular físico -> IP do PC (via --dart-define=API_URL=...)
const String baseUrl =
String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

class Api {
  static Future<int?> usuarioId() async =>
      (await SharedPreferences.getInstance()).getInt('uid');

  static Exception _erro(http.Response r) {
    try {
      return Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Erro');
    } catch (_) {
      return Exception('Erro ${r.statusCode}');
    }
  }

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
    if (r.statusCode != 200) throw _erro(r);
    final uid = jsonDecode(r.body)['usuario_id'] as int;
    (await SharedPreferences.getInstance()).setInt('uid', uid);
  }

  static Future<List<dynamic>> cidades(int uid) async {
    final r = await http.get(Uri.parse('$baseUrl/cidades/$uid'));
    if (r.statusCode != 200) throw _erro(r);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<void> adicionarCidade(int uid, String nome) async {
    final r = await http.post(Uri.parse('$baseUrl/cidades/$uid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cidade': nome}));
    if (r.statusCode != 200) throw _erro(r);
  }

  static Future<void> removerCidade(int uid, int cidadeId) async {
    final r = await http.delete(Uri.parse('$baseUrl/cidades/$uid/$cidadeId'));
    if (r.statusCode != 200) throw _erro(r);
  }

  static Future<Map<String, dynamic>> previsao(int uid, {int? cidadeId}) async {
    final q = cidadeId != null ? '?cidade_id=$cidadeId' : '';
    final r = await http.get(Uri.parse('$baseUrl/previsao/$uid$q'));
    if (r.statusCode != 200) throw _erro(r);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<List<dynamic>> alertas(int uid) async {
    final r = await http.get(Uri.parse('$baseUrl/alertas/$uid'));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<void> testar(int uid) =>
      http.post(Uri.parse('$baseUrl/testar/$uid'));
}