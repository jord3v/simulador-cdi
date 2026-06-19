import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/simulation.dart';

class ResultsScreen extends StatelessWidget {
  final SimulationResult simulation;

  const ResultsScreen({super.key, required this.simulation});

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Análise de Resultados', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryWidgets(),
            const SizedBox(height: 24),
            _buildChartSection(),
            const SizedBox(height: 24),
            const Text('Extrato Diário', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _buildExtratoList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryWidgets() {
    return Row(
      children: [
        Expanded(child: _buildInfoCard('Total Aportado', _formatCurrency(simulation.totalAportado), false)),
        const SizedBox(width: 8),
        Expanded(child: _buildInfoCard('Lucro Líquido', '+${_formatCurrency(simulation.lucroTotal)}', true)),
        const SizedBox(width: 8),
        Expanded(child: _buildInfoCard('Resgate Final', _formatCurrency(simulation.valorFinal), false)),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, bool isHighlight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF0F172A) : Colors.white,
        border: Border.all(color: isHighlight ? const Color(0xFF0F172A) : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          Text(
            title.toUpperCase(), 
            style: TextStyle(
              fontSize: 9, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 0.5,
              color: isHighlight ? const Color(0xFF34D399) : const Color(0xFF64748B)
            ), 
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value, 
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w900, 
              color: isHighlight ? Colors.white : const Color(0xFF0F172A)
            ), 
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    List<FlSpot> spots = [];
    for (int i = 0; i < simulation.resultados.length; i++) {
      spots.add(FlSpot(i.toDouble(), simulation.resultados[i].resgateLiquido));
    }

    return Container(
      height: 320,
      padding: const EdgeInsets.only(right: 24, left: 16, top: 24, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 20),
            child: Text('Evolução do Patrimônio', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: simulation.resultados.length.toDouble() > 0 ? simulation.resultados.length.toDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(simulation.resultados.first.data.substring(0, 5), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          );
                        }
                        if (value.toInt() == simulation.resultados.length - 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(simulation.resultados.last.data.substring(0, 5), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final textStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14);
                        return LineTooltipItem(_formatCurrency(touchedSpot.y), textStyle);
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF34D399), // Emerald 400
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF34D399).withOpacity(0.4),
                          const Color(0xFF34D399).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtratoList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: simulation.resultados.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          // Changed to ascending order (index instead of length - 1 - index)
          final dia = simulation.resultados[index]; 
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: Center(
                    child: Text(
                      dia.data.substring(0, 2),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dia.data, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(_formatCurrency(dia.resgateLiquido), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dia.isWeekend || dia.isHoliday)
                      Text(dia.isHoliday ? (dia.holidayName ?? 'Feriado') : 'Fim de Semana', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500))
                    else ...[
                      Text('+${_formatCurrency(dia.rendimentoLiquidoDia)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                      if (dia.valorIof + dia.valorIr > 0)
                        Text('Impostos: -${_formatCurrency(dia.valorIof + dia.valorIr)}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w600))
                    ]
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
