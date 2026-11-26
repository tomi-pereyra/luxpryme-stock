import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';

class BatchChangeCategoryDialog extends StatefulWidget {
  final String? initialSourceCategoryId;
  final String? initialSectorId;
  final bool onlyArchived;

  const BatchChangeCategoryDialog({
    super.key,
    this.initialSourceCategoryId,
    this.initialSectorId,
    this.onlyArchived = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialSourceCategoryId,
    String? initialSectorId,
    bool onlyArchived = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchChangeCategoryDialog(
        initialSourceCategoryId: initialSourceCategoryId,
        initialSectorId: initialSectorId,
        onlyArchived: onlyArchived,
      ),
    );
  }

  @override
  State<BatchChangeCategoryDialog> createState() =>
      _BatchChangeCategoryDialogState();
}

class _BatchChangeCategoryDialogState extends State<BatchChangeCategoryDialog> {
  static const String uncategorizedKey = '__uncategorized__';
  static const String removeCategoryKey = '__remove_only__';

  String? _sourceCategoryId;
  String? _targetCategoryId;
  bool _showAllSectorCategories = false;

  final Set<String> _selectedProductIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _activeFilterQuery = '';
  bool _isFilterPreservedAfterSelection = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sourceCategoryId = widget.initialSourceCategoryId;
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _searchDebounce?.cancel();
    final text = _searchController.text;
    if (_isFilterPreservedAfterSelection) {
      if (text.isEmpty) return;
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _isFilterPreservedAfterSelection = false;
          _activeFilterQuery = text.trim();
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      return;
    }

    if (text.trim().isEmpty) {
      if (_activeFilterQuery.isNotEmpty) {
        setState(() => _activeFilterQuery = '');
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = text.trim();
      if (_activeFilterQuery != trimmed) {
        setState(() {
          _activeFilterQuery = trimmed;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onToggleProduct(ProductModel product) {
    _searchDebounce?.cancel();
    setState(() {
      if (_selectedProductIds.contains(product.id)) {
        _selectedProductIds.remove(product.id);
      } else {
        _selectedProductIds.add(product.id);
        if (_activeFilterQuery.isNotEmpty) {
          _isFilterPreservedAfterSelection = true;
        }
        _searchController.clear();
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleConfirm(
    List<CategoryModel> availableCategories,
  ) async {
    if (_selectedProductIds.isEmpty) return;
    if (_targetCategoryId == null || _targetCategoryId!.isEmpty) {
      setState(() => _errorMessage = 'Selecione a nova categoria de destino.');
      return;
    }
    if (_targetCategoryId == _sourceCategoryId) {
      setState(() => _errorMessage = 'A categoria de destino deve ser diferente da categoria atual.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final isRemovingOnly = _targetCategoryId == removeCategoryKey;
      final effectiveTargetId = isRemovingOnly ? null : _targetCategoryId;
      final effectiveSourceId =
          _sourceCategoryId == uncategorizedKey ? null : _sourceCategoryId;

      final count = await InventoryService.instance.bulkChangeProductsCategory(
        productIds: _selectedProductIds.toList(),
        sourceCategoryId: effectiveSourceId,
        targetCategoryId: effectiveTargetId,
      );

      String targetName = 'Sem Categoria';
      if (!isRemovingOnly) {
        final match = availableCategories.where((c) => c.id == effectiveTargetId);
        if (match.isNotEmpty) targetName = match.first.name;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              isRemovingOnly
                  ? '$count produto(s) removido(s) da categoria com sucesso!'
                  : '$count produto(s) transferido(s) para a categoria "$targetName"!',
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
    final sectorId = widget.initialSectorId ?? 'todas';
    final hasSpecificSector =
        sectorId.trim().isNotEmpty && sectorId.toLowerCase() != 'todas';

    return StreamBuilder<List<ProductModel>>(
      stream: InventoryService.instance.streamProducts(),
      builder: (context, prodSnap) {
        final allStreamProducts =
            prodSnap.data ?? InventoryService.instance.currentProducts;
        final scopedByArchive = allStreamProducts
            .where((p) => p.isArchived == widget.onlyArchived)
            .toList();

        return StreamBuilder<List<CategoryModel>>(
          stream: InventoryService.instance.streamCategories(),
          builder: (context, catSnap) {
            final allCategories =
                catSnap.data ?? InventoryService.instance.currentCategories;

            final List<CategoryModel> visibleCategories =
                (!_showAllSectorCategories && hasSpecificSector)
                    ? InventoryService.instance.getCategoriesForSector(
                        sectorId,
                        allCategories: allCategories,
                        products: allStreamProducts,
                        onlyArchived: widget.onlyArchived,
                      )
                    : allCategories;

            // Garante que _sourceCategoryId seja válido
            if (_sourceCategoryId == null ||
                (_sourceCategoryId != uncategorizedKey &&
                    !visibleCategories.any((c) => c.id == _sourceCategoryId))) {
              if (widget.initialSourceCategoryId != null &&
                  allCategories.any((c) => c.id == widget.initialSourceCategoryId)) {
                _sourceCategoryId = widget.initialSourceCategoryId;
              } else if (visibleCategories.isNotEmpty) {
                _sourceCategoryId = visibleCategories.first.id;
              } else {
                _sourceCategoryId = uncategorizedKey;
              }
            }

            // Garante que _targetCategoryId seja válido e diferente de _sourceCategoryId
            final targetOptions = visibleCategories
                .where((c) => c.id != _sourceCategoryId)
                .toList();

            if (_targetCategoryId == null ||
                _targetCategoryId == _sourceCategoryId ||
                (_targetCategoryId != removeCategoryKey &&
                    !targetOptions.any((c) => c.id == _targetCategoryId))) {
              if (targetOptions.isNotEmpty) {
                _targetCategoryId = targetOptions.first.id;
              } else if (_sourceCategoryId != uncategorizedKey) {
                _targetCategoryId = removeCategoryKey;
              } else {
                _targetCategoryId = null;
              }
            }

            // Filtra produtos pertencentes à categoria de origem escolhida
            final productsInSourceCategory = scopedByArchive.where((p) {
              if (!_showAllSectorCategories &&
                  hasSpecificSector &&
                  !p.masterCategories.any(
                      (m) => m.toLowerCase() == sectorId.toLowerCase())) {
                return false;
              }
              if (_sourceCategoryId == uncategorizedKey) {
                return p.categoryIds.isEmpty;
              }
              return p.categoryIds.contains(_sourceCategoryId);
            }).toList();

            final filteredProducts = _activeFilterQuery.isEmpty
                ? productsInSourceCategory
                : ProductModel.filterAndSortByRelevance(
                    productsInSourceCategory,
                    _activeFilterQuery,
                  );

            final allVisibleSelected = filteredProducts.isNotEmpty &&
                filteredProducts.every((p) => _selectedProductIds.contains(p.id));

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 660, maxHeight: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trocar Categoria de Produtos',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Selecione produtos de uma categoria e transfira para outra',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasSpecificSector)
                            FilterChip(
                              label: Text(
                                _showAllSectorCategories
                                    ? 'Todos os setores'
                                    : 'Só deste setor',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              selected: !_showAllSectorCategories,
                              selectedColor: AppColors.primaryContainer,
                              checkmarkColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                setState(() {
                                  _showAllSectorCategories =
                                      !_showAllSectorCategories;
                                  _selectedProductIds.clear();
                                });
                              },
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Painel de Origem -> Destino
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              // 1. Categoria Atual (Origem)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '1. Categoria Atual (Origem):',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _sourceCategoryId,
                                          isExpanded: true,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          items: [
                                            ...visibleCategories.map((cat) {
                                              final count = scopedByArchive
                                                  .where((p) => p.categoryIds
                                                      .contains(cat.id))
                                                  .length;
                                              return DropdownMenuItem<String>(
                                                value: cat.id,
                                                child: Text(
                                                  '${cat.name} ($count)',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }),
                                            DropdownMenuItem<String>(
                                              value: uncategorizedKey,
                                              child: Text(
                                                'Sem Categoria (${scopedByArchive.where((p) => p.categoryIds.isEmpty).length})',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _sourceCategoryId = val;
                                                _selectedProductIds.clear();
                                                _isFilterPreservedAfterSelection =
                                                    false;
                                                _activeFilterQuery = '';
                                                _searchController.clear();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding:
                                    EdgeInsets.only(left: 10, right: 10, top: 18),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              // 2. Nova Categoria (Destino)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '2. Nova Categoria (Destino):',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.primary,
                                            width: 1.2),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _targetCategoryId,
                                          isExpanded: true,
                                          hint: const Text(
                                              'Escolha o destino...'),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryDark,
                                          ),
                                          items: [
                                            ...targetOptions.map((cat) {
                                              return DropdownMenuItem<String>(
                                                value: cat.id,
                                                child: Text(
                                                  cat.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }),
                                            if (_sourceCategoryId !=
                                                uncategorizedKey)
                                              const DropdownMenuItem<String>(
                                                value: removeCategoryKey,
                                                child: Text(
                                                  'Remover categoria (Sem Categoria)',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              _targetCategoryId = val;
                                              _errorMessage = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Barra de Busca e Botão Selecionar Todos
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: (_isFilterPreservedAfterSelection &&
                                        _activeFilterQuery.isNotEmpty)
                                    ? 'Selecionado! Digite para buscar outro produto...'
                                    : 'Buscar produto dentro desta categoria...',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 12.5, color: AppColors.textMuted),
                                prefixIcon: const Icon(Icons.search,
                                    color: AppColors.primary, size: 19),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty ||
                                        _isFilterPreservedAfterSelection)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 17),
                                        tooltip: 'Limpar busca',
                                        onPressed: () {
                                          setState(() {
                                            _isFilterPreservedAfterSelection =
                                                false;
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
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 24, minHeight: 24),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${_selectedProductIds.length}',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ),
                          if (filteredProducts.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: Icon(
                                allVisibleSelected
                                    ? Icons.deselect_outlined
                                    : Icons.select_all_outlined,
                                size: 16,
                              ),
                              label: Text(
                                allVisibleSelected
                                    ? 'Desmarcar'
                                    : 'Todos (${filteredProducts.length})',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (allVisibleSelected) {
                                    for (final p in filteredProducts) {
                                      _selectedProductIds.remove(p.id);
                                    }
                                  } else {
                                    for (final p in filteredProducts) {
                                      _selectedProductIds.add(p.id);
                                    }
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF991B1B)),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Lista de Produtos da Categoria Atual
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.folder_open_outlined,
                                      size: 44,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _activeFilterQuery.isNotEmpty
                                          ? 'Nenhum produto encontrado para "$_activeFilterQuery" nesta categoria.'
                                          : 'Não há produtos cadastrados nesta categoria.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              itemCount: filteredProducts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final isSelected =
                                    _selectedProductIds.contains(product.id);

                                return InkWell(
                                  onTap: () => _onToggleProduct(product),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEFF6FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                  if (product.internalCode !=
                                                          null &&
                                                      product.internalCode!
                                                          .isNotEmpty)
                                                    Text(
                                                      'Cód: ${product.internalCode}',
                                                      style: GoogleFonts
                                                          .robotoMono(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                    ),
                                                  if (product.manufacturerCode !=
                                                          null &&
                                                      product.manufacturerCode!
                                                          .isNotEmpty)
                                                    Text(
                                                      'P/N: ${product.manufacturerCode}',
                                                      style: GoogleFonts
                                                          .robotoMono(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  Text(
                                                    'Estoque: ${product.quantity} ${product.unitSymbol}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
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
                            ),
                    ),

                    // Rodapé
                    const Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_selectedProductIds.length} produto(s) selecionado(s)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.swap_horiz_rounded, size: 18),
                            label: Text(
                              _isSaving
                                  ? 'Transferindo...'
                                  : 'Trocar Categoria',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                            onPressed: (_selectedProductIds.isEmpty ||
                                    _targetCategoryId == null ||
                                    _isSaving)
                                ? null
                                : () => _handleConfirm(allCategories),
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
    );
  }
}
