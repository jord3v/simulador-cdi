class ResultadoDia {
  final String data;
  final double taxaDia;
  final double rendimentoDia;
  final double valorAcumulado;
  final double valorIof;
  final double valorIr;
  final double resgateLiquido;
  final double rendimentoLiquidoDia;
  final bool isProjecao;
  final bool isWeekend;
  final bool isHoliday;
  final String? holidayName;
  final bool isAporteDay;

  ResultadoDia({
    required this.data,
    required this.taxaDia,
    required this.rendimentoDia,
    required this.valorAcumulado,
    required this.valorIof,
    required this.valorIr,
    required this.resgateLiquido,
    required this.rendimentoLiquidoDia,
    required this.isProjecao,
    required this.isWeekend,
    required this.isHoliday,
    this.holidayName,
    required this.isAporteDay,
  });

  factory ResultadoDia.fromJson(Map<String, dynamic> json) {
    return ResultadoDia(
      data: json['data'] as String,
      taxaDia: (json['taxaDia'] as num).toDouble(),
      rendimentoDia: (json['rendimentoDia'] as num).toDouble(),
      valorAcumulado: (json['valorAcumulado'] as num).toDouble(),
      valorIof: (json['valorIof'] as num).toDouble(),
      valorIr: (json['valorIr'] as num).toDouble(),
      resgateLiquido: (json['resgateLiquido'] as num).toDouble(),
      rendimentoLiquidoDia: (json['rendimentoLiquidoDia'] as num).toDouble(),
      isProjecao: json['isProjecao'] as bool? ?? false,
      isWeekend: json['isWeekend'] as bool? ?? false,
      isHoliday: json['isHoliday'] as bool? ?? false,
      holidayName: json['holidayName'] as String?,
      isAporteDay: json['isAporteDay'] as bool? ?? false,
    );
  }
}

class SimulationResult {
  final List<ResultadoDia> resultados;
  final double valorFinal;
  final double lucroTotal;
  final double totalAportado;
  final String taxaAtual;

  SimulationResult({
    required this.resultados,
    required this.valorFinal,
    required this.lucroTotal,
    required this.totalAportado,
    required this.taxaAtual,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    var list = json['resultados'] as List;
    List<ResultadoDia> resultadosList = list.map((i) => ResultadoDia.fromJson(i)).toList();

    return SimulationResult(
      resultados: resultadosList,
      valorFinal: (json['valorFinal'] as num).toDouble(),
      lucroTotal: (json['lucroTotal'] as num).toDouble(),
      totalAportado: (json['totalAportado'] as num).toDouble(),
      taxaAtual: json['taxaAtual'].toString(),
    );
  }
}
