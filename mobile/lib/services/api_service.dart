import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/simulation.dart';

class ApiService {
  // Use localhost if running on Web (Edge/Chrome), else use Android Emulator alias
  static const String baseUrl = kIsWeb 
      ? 'http://localhost:8787/api/cdi' 
      : 'http://10.0.2.2:8787/api/cdi';

  static Future<SimulationResult> fetchSimulation({
    required double valorInicial,
    required double percentualCdi,
    required String dataInicial,
    required double aporteMensal,
    required int diaAporte,
    String? dataFinal,
  }) async {
    final queryParams = {
      'valorInicial': valorInicial.toString(),
      'percentualCdi': percentualCdi.toString(),
      'dataInicial': dataInicial,
      'aporteMensal': aporteMensal.toString(),
      'diaAporte': diaAporte.toString(),
    };

    if (dataFinal != null && dataFinal.isNotEmpty) {
      queryParams['dataFinal'] = dataFinal;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return SimulationResult.fromJson(json.decode(response.body));
    } else {
      final errorJson = json.decode(response.body);
      throw Exception(errorJson['error'] ?? 'Erro desconhecido da API');
    }
  }
}
