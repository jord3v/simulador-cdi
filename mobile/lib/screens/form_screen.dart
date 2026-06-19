import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'results_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recent_search.dart';
import 'history_screen.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _valorInicialController = TextEditingController(text: '1000');
  final _percentualCdiController = TextEditingController(text: '100');
  final _aporteMensalController = TextEditingController(text: '0');
  final _diaAporteController = TextEditingController(text: '1');
  
  DateTime _dataInicial = DateTime(DateTime.now().year, 1, 1);
  DateTime? _dataFinal;
  
  bool _isLoading = false;

  Future<void> _saveRecentSearch(RecentSearch search) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recentSearches') ?? [];
    final oldList = jsonList.map((j) => RecentSearch.fromJson(j)).toList();
    
    final newList = [search, ...oldList];
    // Keep only unique searches
    final List<RecentSearch> uniqueList = [];
    for (var s in newList) {
      if (!uniqueList.any((e) => e.valorInicial == s.valorInicial && e.aporteMensal == s.aporteMensal && e.percentualCdi == s.percentualCdi && e.dataInicial == s.dataInicial)) {
        uniqueList.add(s);
      }
      // No strict cap to allow full list
      if (uniqueList.length >= 100) break;
    }
    await prefs.setStringList('recentSearches', uniqueList.map((s) => s.toJson()).toList());
  }

  Future<void> _selectDate(BuildContext context, bool isInitial) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInitial ? _dataInicial : (_dataFinal ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981), // Emerald
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInitial) {
          _dataInicial = picked;
        } else {
          _dataFinal = picked;
        }
      });
    }
  }

  void _simular() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final DateFormat formatter = DateFormat('dd/MM/yyyy');
      
      final result = await ApiService.fetchSimulation(
        valorInicial: double.parse(_valorInicialController.text),
        percentualCdi: double.parse(_percentualCdiController.text),
        dataInicial: formatter.format(_dataInicial),
        aporteMensal: double.parse(_aporteMensalController.text),
        diaAporte: int.parse(_diaAporteController.text),
        dataFinal: _dataFinal != null ? formatter.format(_dataFinal!) : null,
      );

      final newSearch = RecentSearch(
        valorInicial: double.parse(_valorInicialController.text),
        percentualCdi: double.parse(_percentualCdiController.text),
        aporteMensal: double.parse(_aporteMensalController.text),
        diaAporte: int.parse(_diaAporteController.text),
        dataInicial: formatter.format(_dataInicial),
        timestamp: DateTime.now().toIso8601String(),
      );
      _saveRecentSearch(newSearch);

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(simulation: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF34D399)),
            const SizedBox(width: 8),
            const Text('Simulador ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('CDI', style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFF34D399).withOpacity(0.9))),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure seu Cenário',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Projete seus ganhos com juros compostos em tempo real.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              
              _buildModernInput(
                label: 'Qual a taxa do CDI?',
                controller: _percentualCdiController,
                icon: Icons.percent,
                suffixText: '%',
              ),
              const SizedBox(height: 20),
              
              _buildModernInput(
                label: 'Investimento Inicial',
                controller: _valorInicialController,
                icon: Icons.attach_money,
                prefixText: 'R\$ ',
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildModernInput(
                      label: 'Aporte Mensal',
                      controller: _aporteMensalController,
                      icon: Icons.savings_outlined,
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildModernInput(
                      label: 'Dia Aporte',
                      controller: _diaAporteController,
                      icon: Icons.calendar_today,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              _buildDateSelector(
                title: 'Data Inicial',
                date: _dataInicial,
                onTap: () => _selectDate(context, true),
              ),
              const SizedBox(height: 12),
              _buildDateSelector(
                title: 'Data do Resgate',
                date: _dataFinal,
                isOptional: true,
                onTap: () => _selectDate(context, false),
              ),
              
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _simular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald 500
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('SIMULAR AGORA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryScreen(
                        onSelect: (search) {
                          setState(() {
                            _valorInicialController.text = search.valorInicial.toString().replaceAll('.0', '');
                            _percentualCdiController.text = search.percentualCdi.toString().replaceAll('.0', '');
                            _aporteMensalController.text = search.aporteMensal.toString().replaceAll('.0', '');
                            _diaAporteController.text = search.diaAporte.toString();
                            _dataInicial = DateFormat('dd/MM/yyyy').parse(search.dataInicial);
                            _dataFinal = null;
                          });
                          _simular();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history, color: Color(0xFF64748B)),
                label: const Text('Ver Histórico de Consultas', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 40),
              
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Colors.black12),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 16,
          children: [
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://jorgemiguel.wc4.com.br/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.network(
                    'https://jorgemiguel.wc4.com.br/favicon.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('CRIADO POR', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1)),
                      Text('Jorge Miguel', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://github.com/jord3v/simulador-cdi');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, size: 24, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('CÓDIGO FONTE', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1)),
                      Text('GitHub', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }


  Widget _buildModernInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? prefixText,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
          prefixText: prefixText,
          suffixText: suffixText,
          prefixStyle: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          suffixStyle: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
      ),
    );
  }

  Widget _buildDateSelector({required String title, DateTime? date, bool isOptional = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Até hoje',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: date != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
