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
  last30Days('Últimos 30 dias'),
  custom('Data Específica...');

  final String label;
  const HistoryPeriodFilter(this.label);
}

enum HistoryQuantityFilter {
  all('Todas Quantidades'),
  onlyExits('Apenas Saídas (-)'),
  onlyEntries('Apenas Entradas (+)'),
  largeMovements('Grandes (≥ 50 un)');

  final String label;
  const HistoryQuantityFilter(this.label);
}

enum HistorySourceFilter {
  all('Todas as Origens'),
  onlyCart('Apenas Carrinho'),
  onlyDirect('Apenas Ajustes Diretos');

  final String label;
  const HistorySourceFilter(this.label);
}

enum HistorySortOrder {
  recentFirst('Mais Recente Primeiro'),
  oldestFirst('Mais Antigo Primeiro');

  final String label;
  const HistorySortOrder(this.label);
}

abstract class HistoryItemEntry {}

class SingleMovementEntry extends HistoryItemEntry {
  final StockMovementModel movement;
  SingleMovementEntry(this.movement);
}

class GroupedUnitMovementEntry extends HistoryItemEntry {
  final String groupKey;
  final String operatorName;
  final DateTime startTime;
  final DateTime endTime;
  final List<StockMovementModel> movements;

  GroupedUnitMovementEntry({
    required this.groupKey,
    required this.operatorName,
    required this.startTime,
    required this.endTime,
    required this.movements,
  });

  int get totalNetDelta => movements.fold(0, (sum, m) => sum + m.delta);
  int get totalAdditions => movements.where((m) => m.delta > 0).fold(0, (sum, m) => sum + m.delta);
  int get totalRemovals => movements.where((m) => m.delta < 0).fold(0, (sum, m) => sum + m.delta.abs());
}

class HistoryScreen extends StatefulWidget {
  final List<CategoryModel> categories;

  const HistoryScreen({super.key, required this.categories});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _itemSearchController = TextEditingController();
  bool _isFiltersExpanded = false;

  bool get _hasActiveFilters =>
      _selectedSourceFilter != HistorySourceFilter.all ||
      _selectedOperator != null ||
      _selectedCategoryName != null ||
      _selectedPeriod != HistoryPeriodFilter.all ||
      _selectedQtyFilter != HistoryQuantityFilter.all;

  String _searchItemQuery = '';
  String? _selectedCategoryName;
  String? _selectedOperator;
  DateTime? _selectedSpecificDate;
  HistoryPeriodFilter _selectedPeriod = HistoryPeriodFilter.all;
  HistoryQuantityFilter _selectedQtyFilter = HistoryQuantityFilter.all;
  HistorySourceFilter _selectedSourceFilter = HistorySourceFilter.all;
  HistorySortOrder _selectedSortOrder = HistorySortOrder.recentFirst;
  final Set<String> _expandedGroupKeys = {};

  List<HistoryItemEntry> _groupMovementsForDisplay(List<StockMovementModel> movements) {
    if (movements.isEmpty) return [];

    final List<HistoryItemEntry> entries = [];
    int i = 0;

    while (i < movements.length) {
      final current = movements[i];
      final isUnitAdjust = current.type == 'UNIT_ADD' || current.type == 'UNIT_REMOVE';

      if (!isUnitAdjust) {
        entries.add(SingleMovementEntry(current));
        i++;
        continue;
      }

      // Procura ajustes unitários consecutivos no mesmo momento (janela de até 90s entre eventos com mesmo operador)
      final cluster = <StockMovementModel>[current];
      int j = i + 1;

      while (j < movements.length) {
        final next = movements[j];
        final nextIsUnit = next.type == 'UNIT_ADD' || next.type == 'UNIT_REMOVE';

        if (!nextIsUnit) break;
        if (next.operatorName.trim().toLowerCase() != current.operatorName.trim().toLowerCase()) break;

        final diffSec = next.createdAt.difference(cluster.last.createdAt).inSeconds.abs();
        if (diffSec > 90) break;

        cluster.add(next);
        j++;
      }

      if (cluster.length > 1) {
        final startTime = cluster.first.createdAt;
        final endTime = cluster.last.createdAt;
        final groupKey = '${current.operatorName}_${startTime.millisecondsSinceEpoch}_${cluster.length}';
        entries.add(GroupedUnitMovementEntry(
          groupKey: groupKey,
          operatorName: current.operatorName,
          startTime: startTime,
          endTime: endTime,
          movements: cluster,
        ));
        i = j;
      } else {
        entries.add(SingleMovementEntry(current));
        i++;
      }
    }

    return entries;
  }

  @override
  void initState() {
    super.initState();
    _itemSearchController.addListener(() {
      setState(() {
        _searchItemQuery = _itemSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickSpecificDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSpecificDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECIONE A DATA DO HISTÓRICO',
      cancelText: 'CANCELAR',
      confirmText: 'FILTRAR',
    );

    if (picked != null) {
      setState(() {
        _selectedSpecificDate = picked;
        _selectedPeriod = HistoryPeriodFilter.custom;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedSpecificDate = null;
      _selectedPeriod = HistoryPeriodFilter.all;
    });
  }

  List<StockMovementModel> _applyFilters(List<StockMovementModel> movements) {
    final filtered = movements.where((m) {
      // 1. Filtro por Busca Desordenada (Nome, Código Interno, P/N)
      if (_searchItemQuery.isNotEmpty) {
        final tokens = _searchItemQuery
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty);

        final fullText = [
          m.productName,
          m.internalCode ?? '',
          m.manufacturerCode ?? '',
          m.productCode ?? '',
        ].join(' ').toLowerCase();

        final matchesAllTokens = tokens.every((token) => fullText.contains(token));
        if (!matchesAllTokens) return false;
      }

      // 2. Filtro por Origem (Carrinho vs Ajuste Direto)
      final isCartMovement = m.type.toUpperCase().startsWith('CART_');
      switch (_selectedSourceFilter) {
        case HistorySourceFilter.all:
          break;
        case HistorySourceFilter.onlyCart:
          if (!isCartMovement) return false;
          break;
        case HistorySourceFilter.onlyDirect:
          if (isCartMovement) return false;
          break;
      }

      // 3. Filtro por Pessoa / Operador (PIN)
      if (_selectedOperator != null && _selectedOperator!.isNotEmpty) {
        if (m.operatorName.trim().toLowerCase() !=
            _selectedOperator!.trim().toLowerCase()) {
          return false;
        }
      }

      // 4. Filtro por Categoria
      if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty) {
        if (!m.categoryNames.contains(_selectedCategoryName)) return false;
      }

      // 5. Filtro por Quantidade / Tipo (+ / - / grandes)
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

      // 6. Filtro por Data / Período
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
        case HistoryPeriodFilter.custom:
          if (_selectedSpecificDate != null) {
            if (m.createdAt.year != _selectedSpecificDate!.year ||
                m.createdAt.month != _selectedSpecificDate!.month ||
                m.createdAt.day != _selectedSpecificDate!.day) {
              return false;
            }
          }
          break;
      }

      return true;
    }).toList();

    // 7. Ordenação (Mais Recente Primeiro ou Mais Antigo)
    if (_selectedSortOrder == HistorySortOrder.recentFirst) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return filtered;
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
                    '• Período: ${_selectedPeriod == HistoryPeriodFilter.custom && _selectedSpecificDate != null ? DateFormat('dd/MM/yyyy').format(_selectedSpecificDate!) : _selectedPeriod.label}\n'
                    '• Origem: ${_selectedSourceFilter.label}\n'
                    '• Operador (Pessoa): ${_selectedOperator ?? "Todos"}\n'
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
                csvBuffer.writeln('Data;Hora;Produto;Codigo_Int;Part_Number;Qtd;Tipo;Origem;Operador;Observacao');
                for (var m in filteredList) {
                  final dt = DateFormat('dd/MM/yyyy;HH:mm:ss').format(m.createdAt);
                  final isCart = m.type.toUpperCase().startsWith('CART_');
                  final origin = isCart ? 'Carrinho' : 'Ajuste Direto';
                  final note = (m.notes ?? '').replaceAll(';', ',');
                  csvBuffer.writeln(
                      '$dt;${m.productName};${m.internalCode ?? ""};${m.manufacturerCode ?? ""};${m.delta};${m.type};$origin;${m.operatorName};$note');
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
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            return Text(
              isMobile ? 'Histórico' : 'Histórico & Relatórios de Estoque',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Histórico',
            onPressed: () async {
              final list = await InventoryService.instance.fetchMovements();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${list.length} movimentação(ões) carregada(s).'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<StockMovementModel>>(
        stream: InventoryService.instance.streamMovements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && (!snapshot.hasData || (snapshot.data ?? []).isEmpty)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.stockZero),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar histórico: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      onPressed: () => InventoryService.instance.fetchMovements(),
                    ),
                  ],
                ),
              ),
            );
          }

          final allMovements = snapshot.data ?? [];
          final filteredList = _applyFilters(allMovements);
          final displayItems = _groupMovementsForDisplay(filteredList);

          // Extrai operadores únicos presentes no histórico
          final operatorNames = allMovements
              .map((m) => m.operatorName.trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return Column(
            children: [
              // 1. Painel de Filtros Avançados
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Busca desordenada por item
                    TextField(
                      controller: _itemSearchController,
                      decoration: InputDecoration(
                        hintText: 'Filtrar por componente (palavras em qualquer ordem)...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchItemQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _itemSearchController.clear(),
                              )
                            : null,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (MediaQuery.of(context).size.width < 650) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _hasActiveFilters ? AppColors.primaryContainer : AppColors.background,
                                border: Border.all(color: _hasActiveFilters ? AppColors.primary : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune, size: 14, color: _hasActiveFilters ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isFiltersExpanded ? 'Ocultar Filtros' : 'Filtros Avançados',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _hasActiveFilters ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isFiltersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: _hasActiveFilters ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.clear, size: 14, color: AppColors.stockZero),
                              label: const Text('Limpar', style: TextStyle(fontSize: 12, color: AppColors.stockZero)),
                              onPressed: () {
                                setState(() {
                                  _selectedSourceFilter = HistorySourceFilter.all;
                                  _selectedOperator = null;
                                  _selectedCategoryName = null;
                                  _selectedPeriod = HistoryPeriodFilter.all;
                                  _selectedQtyFilter = HistoryQuantityFilter.all;
                                });
                              },
                            ),
                        ],
                      ),
                      if (_isFiltersExpanded) const SizedBox(height: 8),
                    ],

                    // Linha de seletores principais
                    if (MediaQuery.of(context).size.width >= 650 || _isFiltersExpanded)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Origem (Todas / Carrinho / Ajustes Diretos)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HistorySourceFilter>(
                              value: _selectedSourceFilter,
                              isDense: true,
                              items: HistorySourceFilter.values.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        s == HistorySourceFilter.onlyCart
                                            ? Icons.shopping_cart_outlined
                                            : s == HistorySourceFilter.onlyDirect
                                                ? Icons.tune
                                                : Icons.all_inclusive,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(s.label, style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSourceFilter = val);
                              },
                            ),
                          ),
                        ),

                        // Pessoa / Operador (PIN)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedOperator,
                              isDense: true,
                              hint: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline, size: 15, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text('Todas as Pessoas (PIN)', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_outline, size: 15, color: AppColors.textMuted),
                                      SizedBox(width: 6),
                                      Text('Todas as Pessoas', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ...operatorNames.map((name) {
                                  return DropdownMenuItem(
                                    value: name,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person, size: 15, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(name, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedOperator = val);
                              },
                            ),
                          ),
                        ),

                        // Período
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HistoryPeriodFilter>(
                              value: _selectedPeriod,
                              isDense: true,
                              items: HistoryPeriodFilter.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        p == HistoryPeriodFilter.custom && _selectedSpecificDate != null
                                            ? 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedSpecificDate!)}'
                                            : p.label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val == HistoryPeriodFilter.custom) {
                                  _pickSpecificDate();
                                } else if (val != null) {
                                  setState(() {
                                    _selectedPeriod = val;
                                    _selectedSpecificDate = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // Botão de Data Específica se custom
                        if (_selectedSpecificDate != null)
                          InputChip(
                            avatar: const Icon(Icons.event, size: 14, color: AppColors.primary),
                            label: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedSpecificDate!),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: AppColors.primaryContainer,
                            onPressed: _pickSpecificDate,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: _clearDateFilter,
                          ),

                        // Categoria
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedCategoryName,
                              isDense: true,
                              hint: const Text('Todas Categorias', style: TextStyle(fontSize: 12)),
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
                          ),
                        ),

                        // Quantidade / Tipo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HistoryQuantityFilter>(
                              value: _selectedQtyFilter,
                              isDense: true,
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
                          ),
                        ),

                        // Ordenação (Mais Recente Primeiro)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HistorySortOrder>(
                              value: _selectedSortOrder,
                              isDense: true,
                              items: HistorySortOrder.values.map((so) {
                                return DropdownMenuItem(
                                  value: so,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        so == HistorySortOrder.recentFirst
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(so.label, style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSortOrder = val);
                              },
                            ),
                          ),
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
                      displayItems.length == filteredList.length
                          ? '${filteredList.length} movimentações encontradas'
                          : '${filteredList.length} movimentações (${displayItems.length} registros agrupados)',
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
                child: RefreshIndicator(
                  onRefresh: () => InventoryService.instance.fetchMovements(),
                  child: filteredList.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.history_toggle_off,
                                          size: 48, color: AppColors.textMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhuma movimentação registrada com os filtros atuais.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: displayItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = displayItems[index];
                            if (entry is GroupedUnitMovementEntry) {
                              return _buildGroupedCard(entry);
                            } else if (entry is SingleMovementEntry) {
                              return _buildSingleMovementCard(entry.movement);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupedCard(GroupedUnitMovementEntry group) {
    final isExpanded = _expandedGroupKeys.contains(group.groupKey);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final timeFormat = DateFormat('HH:mm:ss');

    final timeLabel = group.startTime.difference(group.endTime).inSeconds.abs() > 5
        ? '${dateFormat.format(group.startTime)} - ${timeFormat.format(group.endTime)}'
        : dateFormat.format(group.startTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded ? AppColors.primary : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header do Grupo
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroupKeys.remove(group.groupKey);
                } else {
                  _expandedGroupKeys.add(group.groupKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Ajustes Unitários (+ / -)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${group.movements.length} itens no mesmo momento',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pessoa: ${group.operatorName}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (group.totalAdditions > 0)
                            Text(
                              '+${group.totalAdditions}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stockNormal,
                              ),
                            ),
                          if (group.totalAdditions > 0 && group.totalRemovals > 0)
                            const Text(' / ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          if (group.totalRemovals > 0)
                            Text(
                              '-${group.totalRemovals}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stockZero,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? 'Ocultar' : 'Ver todos',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Sub-itens expandidos
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Container(
              color: const Color(0xFFF8FAFC),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: group.movements.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, subIdx) {
                  final subM = group.movements[subIdx];
                  final isSubEntry = subM.isEntry;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isSubEntry ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          size: 16,
                          color: isSubEntry ? AppColors.stockNormal : AppColors.stockZero,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subM.productName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (subM.internalCode != null && subM.internalCode!.isNotEmpty)
                                    Text(
                                      'Cód: ${subM.internalCode}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 10,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  if (subM.manufacturerCode != null && subM.manufacturerCode!.isNotEmpty)
                                    Text(
                                      'P/N: ${subM.manufacturerCode}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  Text(
                                    timeFormat.format(subM.createdAt),
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isSubEntry ? "+" : ""}${subM.delta} un',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSubEntry ? AppColors.stockNormal : AppColors.stockZero,
                              ),
                            ),
                            Text(
                              'Saldo: ${subM.newQuantity} un',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
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
        ],
      ),
    );
  }

  Widget _buildSingleMovementCard(StockMovementModel m) {
    final isEntry = m.isEntry;
    final isCart = m.type.toUpperCase().startsWith('CART_');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEntry ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEntry ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
              color: isEntry ? AppColors.stockNormal : AppColors.stockZero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.productName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCart ? AppColors.primaryContainer : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCart ? Icons.shopping_cart_outlined : Icons.tune,
                            size: 11,
                            color: isCart ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isCart ? 'Carrinho' : 'Ajuste Direto',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCart ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  children: [
                    if (m.internalCode != null && m.internalCode!.isNotEmpty)
                      Text(
                        'Cód: ${m.internalCode}',
                        style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.primaryDark),
                      ),
                    if (m.manufacturerCode != null && m.manufacturerCode!.isNotEmpty)
                      Text(
                        'P/N: ${m.manufacturerCode}',
                        style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    Text(
                      'Pessoa: ${m.operatorName}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Obs: ${m.notes!.trim()}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                Text(
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(m.createdAt),
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isEntry ? "+" : ""}${m.delta} un',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isEntry ? AppColors.stockNormal : AppColors.stockZero,
                ),
              ),
              Text(
                'Saldo: ${m.newQuantity} un',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
