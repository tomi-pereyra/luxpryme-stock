import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/models/stock_movement_model.dart';
import '../../data/services/inventory_service.dart';

enum HistoryPeriodFilter {
  all('Todo o Período'),
  today('Hoje'),
  last7Days('Últimos 7 dias'),
  last30Days('Últimos 30 dias');

  final String label;
  const HistoryPeriodFilter(this.label);
}

enum HistoryQuantityFilter {
  all('Todas as Quantidades'),
  onlyExits('Apenas Saídas (Retiradas)'),
  onlyEntries('Apenas Entradas (Reposição)'),
  largeMovements('Grandes Movimentações (≥ 50 un)');

  final String label;
  const HistoryQuantityFilter(this.label);
}

class HistoryScreen extends StatefulWidget {
  final List<CategoryModel> categories;

  const HistoryScreen({super.key, required this.categories});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _itemSearchController = TextEditingController();

  String _searchItemQuery = '';
  String? _selectedCategoryName;
  HistoryPeriodFilter _selectedPeriod = HistoryPeriodFilter.all;
  HistoryQuantityFilter _selectedQtyFilter = HistoryQuantityFilter.all;

  @override
  void initState() {
    super.initState();
    _itemSearchController.addListener(() {
      setState(() {
        _searchItemQuery = _itemSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    super.dispose();
  }

  List<StockMovementModel> _applyFilters(List<StockMovementModel> movements) {
    return movements.where((m) {
      // 1. Filtro por Busca de Item (Nome, Cód. Interno ou P/N)
      if (_searchItemQuery.isNotEmpty) {
        final matchName = m.productName.toLowerCase().contains(_searchItemQuery);
        final matchInt =
            m.internalCode != null && m.internalCode!.toLowerCase().contains(_searchItemQuery);
        final matchMfg =
            m.manufacturerCode != null && m.manufacturerCode!.toLowerCase().contains(_searchItemQuery);
        final matchCode =
            m.productCode != null && m.productCode!.toLowerCase().contains(_searchItemQuery);
        if (!matchName && !matchInt && !matchMfg && !matchCode) return false;
      }

      // 2. Filtro por Categoria
      if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty) {
        if (!m.categoryNames.contains(_selectedCategoryName)) return false;
      }

      // 3. Filtro por Quantidade / Tipo
      switch (_selectedQtyFilter) {
        case HistoryQuantityFilter.all:
          break;
        case HistoryQuantityFilter.onlyExits:
          if (m.delta >= 0) return false;
          break;
        case HistoryQuantityFilter.onlyEntries:
          if (m.delta <= 0) return false;
          break;
        case HistoryQuantityFilter.largeMovements:
          if (m.delta.abs() < 50) return false;
          break;
      }

      // 4. Filtro por Data / Período (Modificados Recentemente)
      final now = DateTime.now();
      switch (_selectedPeriod) {
        case HistoryPeriodFilter.all:
          break;
        case HistoryPeriodFilter.today:
          if (m.createdAt.year != now.year ||
              m.createdAt.month != now.month ||
              m.createdAt.day != now.day) {
            return false;
          }
          break;
        case HistoryPeriodFilter.last7Days:
          if (now.difference(m.createdAt).inDays > 7) return false;
          break;
        case HistoryPeriodFilter.last30Days:
          if (now.difference(m.createdAt).inDays > 30) return false;
          break;
      }

      return true;
    }).toList();
  }

  void _showReportDialog(List<StockMovementModel> filteredList) {
    int totalEntries = 0;
    int totalExits = 0;

    for (var m in filteredList) {
      if (m.delta > 0) {
        totalEntries += m.delta;
      } else {
        totalExits += m.delta.abs();
      }
    }

    final balance = totalEntries - totalExits;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.summarize_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Relatório de Movimentação'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Parâmetros do Relatório:',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Período: ${_selectedPeriod.label}\n'
                    '• Categoria: ${_selectedCategoryName ?? "Todas"}\n'
                    '• Filtro de Item: ${_searchItemQuery.isEmpty ? "Todos os Itens" : _searchItemQuery}\n'
                    '• Total de Movimentações: ${filteredList.length} registros',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Cards de Resumo
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text('Total Entradas',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.stockNormal)),
                              const SizedBox(height: 2),
                              Text('+$totalEntries un',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.stockNormal)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text('Total Saídas',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.stockZero)),
                              const SizedBox(height: 2),
                              Text('-$totalExits un',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.stockZero)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Saldo Líquido no Período:',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          '${balance >= 0 ? "+" : ""}$balance un',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: balance >= 0 ? AppColors.stockNormal : AppColors.stockZero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar Relatório CSV'),
              onPressed: () {
                final csvBuffer = StringBuffer();
                csvBuffer.writeln('Data;Hora;Produto;Codigo_Int;Part_Number;Qtd;Tipo;Operador');
                for (var m in filteredList) {
                  final dt = DateFormat('dd/MM/yyyy;HH:mm').format(m.createdAt);
                  csvBuffer.writeln(
                      '$dt;${m.productName};${m.internalCode ?? ""};${m.manufacturerCode ?? ""};${m.delta};${m.type};${m.operatorName}');
                }
                Clipboard.setData(ClipboardData(text: csvBuffer.toString()));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Relatório CSV copiado para a área de transferência!'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Histórico & Relatórios de Estoque',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<StockMovementModel>>(
        stream: InventoryService.instance.streamMovements(),
        builder: (context, snapshot) {
          final allMovements = snapshot.data ?? [];
          final filteredList = _applyFilters(allMovements);

          return Column(
            children: [
              // 1. Painel de Filtros
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Busca por item específico
                    TextField(
                      controller: _itemSearchController,
                      decoration: InputDecoration(
                        hintText: 'Filtrar por nome, código interno ou P/N...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchItemQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _itemSearchController.clear(),
                              )
                            : null,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Seletores de Período, Categoria e Quantidade
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Período
                        DropdownButton<HistoryPeriodFilter>(
                          value: _selectedPeriod,
                          underline: const SizedBox(),
                          items: HistoryPeriodFilter.values.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p.label, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPeriod = val);
                          },
                        ),

                        // Categoria
                        DropdownButton<String?>(
                          value: _selectedCategoryName,
                          hint: const Text('Todas Categorias', style: TextStyle(fontSize: 12)),
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas Categorias', style: TextStyle(fontSize: 12)),
                            ),
                            ...widget.categories.map((c) {
                              return DropdownMenuItem(
                                value: c.name,
                                child: Text(c.name, style: const TextStyle(fontSize: 12)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedCategoryName = val);
                          },
                        ),

                        // Quantidade / Tipo
                        DropdownButton<HistoryQuantityFilter>(
                          value: _selectedQtyFilter,
                          underline: const SizedBox(),
                          items: HistoryQuantityFilter.values.map((q) {
                            return DropdownMenuItem(
                              value: q,
                              child: Text(q.label, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedQtyFilter = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Barra de Status e Botão de Gerar Relatório
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredList.length} movimentações encontradas',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      icon: const Icon(Icons.assessment_outlined, size: 16),
                      label: Text(
                        'Gerar Relatório',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _showReportDialog(filteredList),
                    ),
                  ],
                ),
              ),

              // Lista de Movimentações
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_toggle_off,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma movimentação registrada com os filtros atuais.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = filteredList[index];
                          final isEntry = m.isEntry;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Ícone de Entrada ou Saída
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isEntry
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                                    size: 18,
                                    color: isEntry ? AppColors.stockNormal : AppColors.stockZero,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Informações do Produto
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.productName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (m.internalCode != null &&
                                              m.internalCode!.isNotEmpty) ...[
                                            Text(
                                              'Cód: ${m.internalCode} • ',
                                              style: GoogleFonts.robotoMono(
                                                  fontSize: 11, color: AppColors.primaryDark),
                                            ),
                                          ],
                                          Text(
                                            'Resp: ${m.operatorName}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm:ss').format(m.createdAt),
                                        style: GoogleFonts.inter(
                                            fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantidade e Saldo
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isEntry ? "+" : ""}${m.delta} un',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isEntry ? AppColors.stockNormal : AppColors.stockZero,
                                      ),
                                    ),
                                    Text(
                                      'Saldo: ${m.newQuantity} un',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
