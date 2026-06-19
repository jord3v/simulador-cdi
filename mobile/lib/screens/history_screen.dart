import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recent_search.dart';

class HistoryScreen extends StatefulWidget {
  final Function(RecentSearch) onSelect;

  const HistoryScreen({super.key, required this.onSelect});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<RecentSearch> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recentSearches') ?? [];
    setState(() {
      _recentSearches = jsonList.map((j) => RecentSearch.fromJson(j)).toList();
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentSearches');
    setState(() {
      _recentSearches = [];
    });
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Histórico'),
        content: const Text('Tem certeza que deseja apagar todas as consultas recentes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearHistory();
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        title: const Text('Histórico de Consultas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_recentSearches.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClearHistory,
              tooltip: 'Limpar Histórico',
            ),
        ],
      ),
      body: _recentSearches.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma consulta recente.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                final search = _recentSearches[index];
                final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                return InkWell(
                  onTap: () {
                    widget.onSelect(search);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.history, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${fmt.format(search.valorInicial)} + ${fmt.format(search.aporteMensal)}/mês', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text('${search.percentualCdi.toString().replaceAll('.0', '')}% CDI • Início: ${search.dataInicial}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
