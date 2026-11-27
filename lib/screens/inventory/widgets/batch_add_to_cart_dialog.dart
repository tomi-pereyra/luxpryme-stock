import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/inventory_service.dart';

class BatchAddToCartDialog extends StatefulWidget {
  final String initialSectorId;
  final VoidCallback? onOpenCart;
  final bool onlyArchived;

  const BatchAddToCartDialog({
    super.key,
    this.initialSectorId = 'todas',
    this.onOpenCart,
    this.onlyArchived = false,
  });

  static Future<void> show(
    BuildContext context, {
    String initialSectorId = 'todas',
    VoidCallback? onOpenCart,
    bool onlyArchived = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchAddToCartDialog(
        initialSectorId: initialSectorId,
        onOpenCart: onOpenCart,
        onlyArchived: onlyArchived,
      ),
    );
  }

  @override
  State<BatchAddToCartDialog> createState() => _BatchAddToCartDialogState();
}

class _BatchAddToCartDialogState extends State<BatchAddToCartDialog> {
  late String _selectedSectorId;
  bool _isWithdrawal = true; // Padrão: Retirar do estoque (Saída)

  /// Mapa de productId -> quantidade selecionada (> 0)
  final Map<String, int> _selectedQuantities = {};
  final Map<String, ProductModel> _selectedProductsById = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _activeFilterQuery = '';
  bool _isFilterPreservedAfterSelection = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSectorId = widget.initialSectorId.trim().isEmpty
        ? 'todas'
        : widget.initialSectorId.toLowerCase();
    _searchController.addListener(_onSearchInputChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
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
    for (final ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    for (final fn in _qtyFocusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  TextEditingController _getQtyController(ProductModel product) {
    return _qtyControllers.putIfAbsent(product.id, () {
      final currentQty = _selectedQuantities[product.id];
      return TextEditingController(
        text: currentQty != null && currentQty > 0 ? '$currentQty' : '',
      );
    });
  }

  FocusNode _getQtyFocusNode(ProductModel product) {
    return _qtyFocusNodes.putIfAbsent(product.id, () => FocusNode());
  }

  void _preserveSearchAndClearInput() {
    _searchDebounce?.cancel();
    if (_activeFilterQuery.isNotEmpty) {
      _isFilterPreservedAfterSelection = true;
    }
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  void _onToggleProductSelection(ProductModel product) {
    final ctrl = _getQtyController(product);
    final qtyFocus = _getQtyFocusNode(product);

    setState(() {
      _errorMessage = null;
      if (_selectedQuantities.containsKey(product.id)) {
        _selectedQuantities.remove(product.id);
        _selectedProductsById.remove(product.id);
        ctrl.clear();
        _searchFocusNode.requestFocus();
      } else {
        if (_isWithdrawal && product.quantity <= 0) {
          _errorMessage =
              'O item "${product.name}" está com estoque 0 ${product.unitSymbol} e não pode ser retirado.';
          return;
        }
        final typed = int.tryParse(ctrl.text.trim()) ?? 0;
        final initialQty = typed > 0 ? typed : 1;
        if (_isWithdrawal && initialQty > product.quantity) {
          _errorMessage =
              'Estoque disponível de "${product.name}" é ${product.quantity} ${product.unitSymbol}.';
          return;
        }
        _selectedQuantities[product.id] = initialQty;
        _selectedProductsById[product.id] = product;
        ctrl.text = '$initialQty';
        ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: ctrl.text.length,
        );
        _preserveSearchAndClearInput();
        qtyFocus.requestFocus();
      }
    });
  }

  void _onQuantityChanged(ProductModel product, String rawValue) {
    final clean = rawValue.trim();
    final parsed = int.tryParse(clean) ?? 0;

    setState(() {
      _errorMessage = null;
      if (parsed <= 0) {
        _selectedQuantities.remove(product.id);
        _selectedProductsById.remove(product.id);
        return;
      }

      if (_isWithdrawal && parsed > product.quantity) {
        _errorMessage =
            'Atenção: Estoque disponível de "${product.name}" é ${product.quantity} ${product.unitSymbol}.';
      }

      _selectedQuantities[product.id] = parsed;
      _selectedProductsById[product.id] = product;
      _preserveSearchAndClearInput();
    });
  }

  void _stepQuantity(ProductModel product, int delta) {
    final ctrl = _getQtyController(product);
    final current = _selectedQuantities[product.id] ??
        (int.tryParse(ctrl.text.trim()) ?? 0);
    final next = current + delta;

    setState(() {
      _errorMessage = null;
      if (next <= 0) {
        _selectedQuantities.remove(product.id);
        _selectedProductsById.remove(product.id);
        ctrl.clear();
        return;
      }
      if (_isWithdrawal && next > product.quantity) {
        _errorMessage =
            'Estoque máximo disponível de "${product.name}" é ${product.quantity} ${product.unitSymbol}.';
        return;
      }
      _selectedQuantities[product.id] = next;
      _selectedProductsById[product.id] = product;
      ctrl.text = '$next';
      _preserveSearchAndClearInput();
    });
  }

  void _handleConfirmAddToCart() {
    if (_selectedQuantities.isEmpty) return;

    // Valida se nenhuma retirada excede o estoque disponível
    if (_isWithdrawal) {
      for (final entry in _selectedQuantities.entries) {
        final prod = _selectedProductsById[entry.key];
        final qty = entry.value;
        if (prod != null && qty > prod.quantity) {
          setState(() {
            _errorMessage =
                'Não é possível retirar $qty ${prod.unitSymbol} de "${prod.name}" (disponível: ${prod.quantity} ${prod.unitSymbol}).';
          });
          return;
        }
      }
    }

    int addedCount = 0;
    int totalUnits = 0;

    for (final entry in _selectedQuantities.entries) {
      final prod = _selectedProductsById[entry.key];
      final qty = entry.value;
      if (prod != null && qty > 0) {
        CartService.instance.addItem(
          product: prod,
          quantity: qty,
          isWithdrawal: _isWithdrawal,
        );
        addedCount++;
        totalUnits += qty;
      }
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$addedCount produto(s) ($totalUnits un/medida) adicionados ao carrinho!',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: widget.onOpenCart != null
            ? SnackBarAction(
                label: 'VER CARRINHO',
                textColor: Colors.amberAccent,
                onPressed: widget.onOpenCart!,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterCategories = InventoryService.instance.masterCategories;
    final actionColor = _isWithdrawal ? AppColors.primary : AppColors.stockNormal;
    final actionBg =
        _isWithdrawal ? AppColors.primaryContainer : const Color(0xFFDCFCE7);
    final totalSelectedItems = _selectedQuantities.length;
    final totalSelectedQuantity =
        _selectedQuantities.values.fold<int>(0, (sum, q) => sum + q);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Column(
          children: [
            // Header com Seleção de Setor e Modo (Retirar / Repor)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_shopping_cart,
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
                          'Adicionar Produtos ao Carrinho',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Filtrar Setor: ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (_selectedSectorId == 'todas' ||
                                        masterCategories.any((m) =>
                                            m.id.toLowerCase() ==
                                            _selectedSectorId))
                                    ? _selectedSectorId
                                    : 'todas',
                                isDense: true,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: actionColor,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'todas',
                                    child: Text('Todos os Setores'),
                                  ),
                                  ...masterCategories.map((mc) {
                                    return DropdownMenuItem(
                                      value: mc.id.toLowerCase(),
                                      child: Text(mc.name),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSectorId = val;
                                      _isFilterPreservedAfterSelection = false;
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

            // Barra de Tipo de Operação: Retirar vs Repor
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.border),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Operação no Carrinho:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.outbox_outlined,
                      size: 15,
                      color: _isWithdrawal
                          ? AppColors.stockZero
                          : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Retirar do Estoque (Saída)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight:
                            _isWithdrawal ? FontWeight.w700 : FontWeight.w500,
                        color: _isWithdrawal
                            ? AppColors.stockZero
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: _isWithdrawal,
                    selectedColor: const Color(0xFFFEE2E2),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _isWithdrawal = true;
                      _errorMessage = null;
                    }),
                  ),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.move_to_inbox_outlined,
                      size: 15,
                      color: !_isWithdrawal
                          ? AppColors.stockNormal
                          : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Repor no Estoque (Entrada)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight:
                            !_isWithdrawal ? FontWeight.w700 : FontWeight.w500,
                        color: !_isWithdrawal
                            ? AppColors.stockNormal
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: !_isWithdrawal,
                    selectedColor: const Color(0xFFDCFCE7),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _isWithdrawal = false;
                      _errorMessage = null;
                    }),
                  ),
                ],
              ),
            ),

            // Barra de Busca Inteligente com Contador em Círculo Azul
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onSubmitted: (_) {
                  _searchDebounce?.cancel();
                  setState(() {
                    _isFilterPreservedAfterSelection = false;
                    _activeFilterQuery = _searchController.text.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: (_isFilterPreservedAfterSelection &&
                          _activeFilterQuery.isNotEmpty)
                      ? 'Item selecionado! Digite para buscar o próximo produto...'
                      : 'Pesquise por nome, código interno ou P/N e informe a qtd à direita...',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search, color: actionColor, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty ||
                          _isFilterPreservedAfterSelection)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Limpar busca e ver todos',
                          onPressed: () {
                            _searchDebounce?.cancel();
                            setState(() {
                              _isFilterPreservedAfterSelection = false;
                              _activeFilterQuery = '';
                              _searchController.clear();
                            });
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      if (totalSelectedItems > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: actionColor,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 26, minHeight: 26),
                          alignment: Alignment.center,
                          child: Text(
                            '$totalSelectedItems',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.stockZero),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),

            // Lista de Produtos com Campo de Quantidade à Direita
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: InventoryService.instance.streamProducts(),
                builder: (context, snapshot) {
                  final allProducts = (snapshot.data ??
                          InventoryService.instance.currentProducts)
                      .where((p) => p.isArchived == widget.onlyArchived)
                      .toList();

                  final scopedProducts = _selectedSectorId == 'todas'
                      ? allProducts
                      : allProducts
                          .where((p) => p.masterCategories.any(
                              (m) => m.toLowerCase() == _selectedSectorId))
                          .toList();

                  final filteredProducts = _activeFilterQuery.isEmpty
                      ? scopedProducts
                      : ProductModel.filterAndSortByRelevance(
                          scopedProducts,
                          _activeFilterQuery,
                        );

                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _activeFilterQuery.isNotEmpty
                              ? 'Nenhum produto encontrado para "$_activeFilterQuery".'
                              : 'Nenhum produto encontrado neste setor.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final isSelected =
                          _selectedQuantities.containsKey(product.id);
                      final selectedQty = _selectedQuantities[product.id] ?? 0;
                      final qtyCtrl = _getQtyController(product);
                      final qtyFocus = _getQtyFocusNode(product);
                      final isExceedingStock = _isWithdrawal &&
                          isSelected &&
                          selectedQty > product.quantity;

                      // Mantém referência atualizada do produto
                      if (isSelected) {
                        _selectedProductsById[product.id] = product;
                      }

                      final sectorLabels = product.masterCategories
                          .map(InventoryService.instance.getMasterCategoryName)
                          .join(' / ');

                      return InkWell(
                        onTap: () => _onToggleProductSelection(product),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isExceedingStock
                                ? const Color(0xFFFEF2F2)
                                : isSelected
                                    ? (_isWithdrawal
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF0FDF4))
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isExceedingStock
                                  ? AppColors.stockZero
                                  : isSelected
                                      ? actionColor
                                      : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox de seleção à esquerda
                              InkWell(
                                onTap: () => _onToggleProductSelection(product),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? actionColor
                                        : AppColors.textMuted,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Dados do produto ao centro
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
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 2,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (product.internalCode != null &&
                                            product.internalCode!.isNotEmpty)
                                          Text(
                                            'Cód: ${product.internalCode}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: Text(
                                            sectorLabels,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Disp: ${product.quantity} ${product.unitSymbol}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: product.quantity > 0
                                                ? AppColors.stockNormal
                                                : AppColors.stockZero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Lado Direito: Controles [-] [Campo de Quantidade] [+]
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    InkWell(
                                      onTap: () => _stepQuantity(product, -1),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 28,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: const Icon(Icons.remove,
                                            size: 15,
                                            color: AppColors.textPrimary),
                                      ),
                                    ),
                                  if (isSelected) const SizedBox(width: 4),
                                  SizedBox(
                                    width: 84,
                                    height: 36,
                                    child: TextField(
                                      controller: qtyCtrl,
                                      focusNode: qtyFocus,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: isExceedingStock
                                            ? AppColors.stockZero
                                            : AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Qtd',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
                                        ),
                                        suffixText: product.unitSymbol,
                                        suffixStyle: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isSelected
                                                ? actionColor
                                                : AppColors.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isExceedingStock
                                                ? AppColors.stockZero
                                                : isSelected
                                                    ? actionColor
                                                    : AppColors.border,
                                            width: isSelected ? 1.4 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: actionColor,
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (val) =>
                                          _onQuantityChanged(product, val),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _stepQuantity(product, 1),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 28,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: actionBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: actionColor
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Icon(Icons.add,
                                          size: 15, color: actionColor),
                                    ),
                                  ),
                                ],
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

            // Rodapé com Resumo e Botão de Confirmar
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$totalSelectedItems item(ns) • Total: $totalSelectedQuantity un/medida',
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(
                      'Adicionar ao Carrinho',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onPressed:
                        totalSelectedItems == 0 ? null : _handleConfirmAddToCart,
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
