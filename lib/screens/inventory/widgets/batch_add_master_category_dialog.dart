import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';

enum BatchItemMode { add, remove }

class BatchAddMasterCategoryDialog extends StatefulWidget {
  final String initialMasterCategoryId;
  final List<MasterCategoryModel> masterCategories;
  final BatchItemMode mode;

  const BatchAddMasterCategoryDialog({
    super.key,
    required this.initialMasterCategoryId,
    required this.masterCategories,
    this.mode = BatchItemMode.add,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialMasterCategoryId,
    required List<MasterCategoryModel> masterCategories,
    BatchItemMode mode = BatchItemMode.add,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchAddMasterCategoryDialog(
        initialMasterCategoryId: initialMasterCategoryId,
        masterCategories: masterCategories,
        mode: mode,
      ),
    );
  }

  @override
  State<BatchAddMasterCategoryDialog> createState() =>
      _BatchAddMasterCategoryDialogState();
}

class _BatchAddMasterCategoryDialogState
    extends State<BatchAddMasterCategoryDialog> {
  late String _selectedMasterCategoryId;
  final Set<String> _selectedProductIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _activeFilterQuery = '';
  bool _isFilterPreservedAfterSelection = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get isAddMode => widget.mode == BatchItemMode.add;

  @override
  void initState() {
    super.initState();
    final validCategories = widget.masterCategories
        .where((mc) => mc.id.toLowerCase() != 'todas')
        .toList();

    if (widget.initialMasterCategoryId.toLowerCase() != 'todas' &&
        validCategories.any((mc) => mc.id == widget.initialMasterCategoryId)) {
      _selectedMasterCategoryId = widget.initialMasterCategoryId;
    } else {
      _selectedMasterCategoryId =
          validCategories.isNotEmpty ? validCategories.first.id : 'eletronica';
    }

    _searchController.addListener(_onSearchInputChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _onSearchInputChanged() {
    final text = _searchController.text;
    if (_isFilterPreservedAfterSelection) {
      // Se o campo de texto foi limpo programaticamente ao selecionar, mantém a lista visível
      // na mesma posição até que o usuário volte a digitar novos caracteres
      if (text.isEmpty) {
        return;
      }
      // O usuário começou a digitar novamente! Atualiza o filtro e reposiciona no topo
      setState(() {
        _isFilterPreservedAfterSelection = false;
        _activeFilterQuery = text.trim();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    setState(() {
      _activeFilterQuery = text.trim();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onToggleProduct(ProductModel product) {
    setState(() {
      if (_selectedProductIds.contains(product.id)) {
        _selectedProductIds.remove(product.id);
      } else {
        _selectedProductIds.add(product.id);
        // Se havia uma busca ativa, congela a lista filtrada visível na posição atual
        if (_activeFilterQuery.isNotEmpty) {
          _isFilterPreservedAfterSelection = true;
        }
        // Apaga o que está escrito no campo de busca para o usuário digitar o próximo item,
        // mas a lista permanece exatamente onde o componente foi selecionado
        _searchController.clear();
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (_selectedProductIds.isEmpty) return;

    final targetCategory = widget.masterCategories.firstWhere(
      (mc) => mc.id == _selectedMasterCategoryId,
      orElse: () => MasterCategoryModel(
        id: _selectedMasterCategoryId,
        name: _selectedMasterCategoryId,
      ),
    );

    final actionLabel = isAddMode ? 'adicionar' : 'remover';
    final preposition = isAddMode ? 'ao setor' : 'do setor';

    final pinController = TextEditingController();
    String? pinError;

    final pinConfirmed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAddMode ? AppColors.primaryContainer : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAddMode ? Icons.admin_panel_settings_outlined : Icons.remove_circle_outline,
                      color: isAddMode ? AppColors.primary : AppColors.stockZero,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Autorização com PIN Mestre'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para $actionLabel ${_selectedProductIds.length} item(ns) $preposition "${targetCategory.name}", digite o PIN de 4 dígitos:',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    obscureText: true,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: '••••',
                      counterText: '',
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        Navigator.of(ctx).pop(val);
                      }
                    },
                  ),
                  if (pinError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      pinError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAddMode ? AppColors.primary : AppColors.stockZero,
                  ),
                  onPressed: () {
                    final p = pinController.text.trim();
                    if (p.length == 4) {
                      Navigator.of(ctx).pop(p);
                    } else {
                      setDialogState(() => pinError = 'Digite exatamente 4 números.');
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pinConfirmed == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (isAddMode) {
        await InventoryService.instance.bulkAddProductsToMasterCategory(
          productIds: _selectedProductIds.toList(),
          targetMasterCategoryId: _selectedMasterCategoryId,
          pin: pinConfirmed,
        );
      } else {
        await InventoryService.instance.bulkRemoveProductsFromMasterCategory(
          productIds: _selectedProductIds.toList(),
          targetMasterCategoryId: _selectedMasterCategoryId,
          pin: pinConfirmed,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isAddMode ? AppColors.stockNormal : AppColors.primary,
            content: Text(
              isAddMode
                  ? 'Sucesso! ${_selectedProductIds.length} produto(s) adicionado(s) ao setor "${targetCategory.name}".'
                  : 'Sucesso! ${_selectedProductIds.length} produto(s) removido(s) do setor "${targetCategory.name}".',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCategories = widget.masterCategories
        .where((mc) => mc.id.toLowerCase() != 'todas')
        .toList();

    final targetCategory = widget.masterCategories.firstWhere(
      (mc) => mc.id == _selectedMasterCategoryId,
      orElse: () => MasterCategoryModel(
        id: _selectedMasterCategoryId,
        name: _selectedMasterCategoryId,
      ),
    );

    final actionColor = isAddMode ? AppColors.primary : AppColors.stockZero;
    final actionBg = isAddMode ? AppColors.primaryContainer : const Color(0xFFFEE2E2);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 750),
        child: Column(
          children: [
            // Header com Seleção da Categoria Alvo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAddMode ? Icons.playlist_add : Icons.playlist_remove,
                      color: actionColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAddMode ? '+ Itens no Setor' : '- Itens do Setor',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            Text(
                              isAddMode ? 'Adicionar ao: ' : 'Remover do: ',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMasterCategoryId,
                                isDense: true,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: actionColor,
                                ),
                                items: validCategories.map((mc) {
                                  return DropdownMenuItem(
                                    value: mc.id,
                                    child: Text(mc.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedMasterCategoryId = val;
                                      _selectedProductIds.clear();
                                      _isFilterPreservedAfterSelection = false;
                                      _activeFilterQuery = '';
                                      _searchController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Barra de Busca no Canto Superior com Contador em Círculo
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: (_isFilterPreservedAfterSelection && _activeFilterQuery.isNotEmpty)
                      ? 'Item selecionado! Digite para buscar outro componente...'
                      : (isAddMode
                          ? 'Pesquise itens fora de ${targetCategory.name}...'
                          : 'Pesquise itens dentro de ${targetCategory.name}...'),
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: actionColor, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty || _isFilterPreservedAfterSelection)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Limpar busca e ver todos',
                          onPressed: () {
                            setState(() {
                              _isFilterPreservedAfterSelection = false;
                              _activeFilterQuery = '';
                              _searchController.clear();
                            });
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      if (_selectedProductIds.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: actionColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          alignment: Alignment.center,
                          child: Text(
                            '${_selectedProductIds.length}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: actionColor, width: 1.5),
                  ),
                ),
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                ),
              ),

            // Lista de Produtos
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: InventoryService.instance.streamProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allProducts = snapshot.data ?? [];
                  // Regra solicitada:
                  // No + itens, produtos já presentes na categoria mestre NÃO aparecem.
                  // No - itens, produtos que NÃO estão na categoria mestre NÃO aparecem.
                  final scopedProducts = isAddMode
                      ? allProducts
                          .where((p) =>
                              !p.masterCategories.contains(_selectedMasterCategoryId))
                          .toList()
                      : allProducts
                          .where((p) =>
                              p.masterCategories.contains(_selectedMasterCategoryId))
                          .toList();

                  final filteredProducts = _activeFilterQuery.isEmpty
                      ? scopedProducts
                      : scopedProducts
                          .where((p) => p.matchesSearch(_activeFilterQuery))
                          .toList();

                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _activeFilterQuery.isNotEmpty
                              ? 'Nenhum item encontrado para "$_activeFilterQuery".'
                              : (isAddMode
                                  ? 'Todos os itens já pertencem ao setor "${targetCategory.name}".'
                                  : 'Nenhum item vinculado ao setor "${targetCategory.name}".'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final isSelected = _selectedProductIds.contains(product.id);

                      return InkWell(
                        onTap: () => _onToggleProduct(product),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isAddMode ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2))
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? actionColor : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? (isAddMode ? Icons.check_circle : Icons.remove_circle)
                                    : Icons.circle_outlined,
                                color: isSelected ? actionColor : AppColors.textMuted,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (product.internalCode != null &&
                                            product.internalCode!.isNotEmpty)
                                          Text(
                                            'Cód: ${product.internalCode}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        if (product.manufacturerCode != null &&
                                            product.manufacturerCode!.isNotEmpty)
                                          Text(
                                            'P/N: ${product.manufacturerCode}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        Text(
                                          'Estoque: ${product.quantity} un',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Rodapé com Ações
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedProductIds.length} item(ns) selecionado(s)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _selectedProductIds.isEmpty || _isSaving ? null : _handleConfirm,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isAddMode
                                ? 'Adicionar ao Setor ${targetCategory.name}'
                                : 'Remover do Setor ${targetCategory.name}',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
