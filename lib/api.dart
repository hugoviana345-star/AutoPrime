import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ErroApi implements Exception {
  final String mensagem;
  final int? status;
  ErroApi(this.mensagem, [this.status]);
  @override
  String toString() => mensagem;
}

class Api {
  // Servidor Python executado no mesmo computador do Chrome.
  static const endereco = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://autoprime-mjt5.onrender.com',
);
  static String? _token;
  static bool visitante = false;
  static bool administrador = false;

  static Future<Map<String, dynamic>> pedido(String metodo, String rota,
      [Map<String, dynamic>? dados]) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    final url = Uri.parse('$endereco$rota');
    try {
      final http.Response resposta;
      if (metodo == 'GET') {
        resposta = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      } else if (metodo == 'PUT') {
        resposta = await http.put(url, headers: headers, body: jsonEncode(dados))
          .timeout(const Duration(seconds: 15));
      } else if (metodo == 'DELETE') {
        resposta = await http.delete(url, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        resposta = await http.post(url, headers: headers, body: jsonEncode(dados ?? {}))
          .timeout(const Duration(seconds: 15));
      }
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      if (resposta.statusCode >= 400) {
        throw ErroApi(corpo['erro'] as String? ?? 'Erro ao acessar o servidor.', resposta.statusCode);
      }
      return corpo;
    } on ErroApi {
      rethrow;
    } on TimeoutException {
      throw ErroApi('O servidor demorou para responder. Tente novamente.');
    } catch (_) {
      throw ErroApi('Não foi possível conectar. Confira se o servidor Python está aberto.');
    }
  }

  static Future<void> cadastrar(String email, String senha) async {
    await pedido('POST', '/register', {'email': email, 'senha': senha});
  }

  static Future<void> entrar(String email, String senha) async {
    final resposta = await pedido('POST', '/login', {'email': email, 'senha': senha});
    _token = resposta['token'] as String;
    visitante = false;
    administrador = resposta['administrador'] == true;
  }

  static Future<void> entrarVisitante() async {
    administrador = false;
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString('autoprime_visitante');
    if (salvo != null) {
      _token = salvo;
      try {
        final resposta = await pedido('GET', '/cart');
        if (resposta['visitante'] == true) {
          visitante = true;
          return;
        }
      } on ErroApi catch (erro) {
        if (erro.status != 401) rethrow;
      }
    }
    _token = null;
    final resposta = await pedido('POST', '/guest');
    final token = resposta['token'] as String;
    if (!await prefs.setString('autoprime_visitante', token)) {
      throw ErroApi('Não foi possível guardar o acesso de visitante neste navegador.');
    }
    _token = token;
    visitante = true;
  }

  static Future<List<dynamic>> carregarCarrinho() async {
    final resposta = await pedido('GET', '/cart');
    return resposta['itens'] as List<dynamic>;
  }

  static Future<void> salvarCarrinho(List<Map<String, dynamic>> itens) async {
    await pedido('PUT', '/cart', {'itens': itens});
  }

  static Future<void> sair() async {
    if (!visitante && _token != null) await pedido('POST', '/logout');
    _token = null;
    visitante = false;
    administrador = false;
  }
}
