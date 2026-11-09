import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente REST. 10.0.2.2 = localhost del PC desde el emulador Android.
class Api {
  static const base = 'http://10.0.2.2:3000/api';
  static String? token;
  static Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };

  static dynamic _r(http.Response r) {
    final b = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400)
      throw Exception(b is Map ? b['error'] : 'Error ${r.statusCode}');
    return b;
  }

  static Future<dynamic> get(String p) async =>
      _r(await http.get(Uri.parse('$base$p'), headers: _h));
  static Future<dynamic> post(String p, [Map? b]) async => _r(await http
      .post(Uri.parse('$base$p'), headers: _h, body: jsonEncode(b ?? {})));
  static Future<dynamic> put(String p, Map b) async => _r(
      await http.put(Uri.parse('$base$p'), headers: _h, body: jsonEncode(b)));
  static Future<dynamic> del(String p) async =>
      _r(await http.delete(Uri.parse('$base$p'), headers: _h));
}
