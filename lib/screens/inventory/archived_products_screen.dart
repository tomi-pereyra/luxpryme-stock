import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/models/master_category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/cart_service.dart';
import '../../data/services/inventory_service.dart';
import 'inventory_screen.dart' show SortOption;
import 'widgets/cart_modal.dart';
import 'widgets/categories_manage_dialog.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/pin_confirmation_dialog.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/batch_change_category_dialog.dart';
import 'widgets/duplicate_stock_dialog.dart';
import 'widgets/sector_report_dialog.dart';

class ArchivedProductsScreen extends StatefulWidget {
  final String initialSectorId;

  const ArchivedProductsScreen({
    super.key,
    this.initialSectorId = 'todas',
  });

  @override
  State<ArchivedProductsScreen> createState() => _ArchivedProductsScreenState();
}

class _ArchivedProductsScreenState extends State<ArchivedProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  late String _selectedMasterCategory;
  String? _selectedCategoryId;
  String? _selectedSubcategory;
  final Set<String> _customSubcategories = {};
  SortOption _selectedSort = SortOption.nameAsc;
  bool _isMobileSearchActive = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _selectedMasterCategory = widget.initialSectorId;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        setState(() => _searchQuery = '');
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      if (_searchQuery != text) {
        setState(() => _searchQuery = text);
      }
    });
  }

  void _applySearchImmediately() {
    _searchDebounce?.cancel();
    final text = _searchController.text.trim();
    if (_searchQuery != text) {
      setState(() => _searchQuery = text);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_searchQuery.isNotEmpty) {
      setState(() => _searchQuery = '');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _openCartModal() {
    showDialog(
      context: context,
      builder: (_) => const CartModal(),
    );
  }

  Future<void> _openEditProductDialog(ProductModel product, List<CategoryModel> categories) async {
    ProductModel target = product;
    if (product.hasSeparateSectorStocks) {
      final picked = await DuplicateStockDialog.pickSectorStock(
        context,
        consolidatedProduct: product,
        actionTitle: 'Editar arquivado de qual setor?',
      );
      if (picked == null || !mounted) return;
      target = picked;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => ProductFormDialog(
        productToEdit: target,
        categories: categories,
      ),
    );
  }

  Future<void> _handleUnarchiveProduct(ProductModel product) async {
    ProductModel target = product;
    if (product.hasSeparateSectorStocks) {
      final picked = await DuplicateStockDialog.pickSectorStock(
        context,
        consolidatedProduct: product,
        actionTitle: 'Desarquivar estoque de qual setor?',
      );
      if (picked == null || !mounted) return;
      target = picked;
    }
    if (!mounted) return;

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Desarquivar Produto',
      subtitle: 'Digite seu PIN de 4 dígitos para retornar este item ao estoque ativo:',
      itemName: target.name,
      actionLabel: 'Desarquivar',
      actionColor: AppColors.stockNormal,
      actionIcon: Icons.unarchive_outlined,
    );

    if (pin == null) return;

    try {
      await InventoryService.instance.unarchiveProduct(target.id, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Item "${target.name}" retornado ao estoque ativo!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockZero,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteProduct(ProductModel product) async {
    ProductModel target = product;
    if (product.hasSeparateSectorStocks) {
      final picked = await DuplicateStockDialog.pickSectorStock(
        context,
        consolidatedProduct: product,
        actionTitle: 'Excluir arquivado de qual setor?',
      );
      if (picked == null || !mounted) return;
      target = picked;
    }
    if (!mounted) return;

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirmar Exclusão',
      subtitle: 'Para mover este item arquivado para a lixeira, digite seu PIN de 4 dígitos:',
      itemName: target.name,
      actionLabel: 'Excluir Produto',
      actionColor: AppColors.stockZero,
      actionIcon: Icons.delete_forever,
    );

    if (pin == null) return;

    try {
      await InventoryService.instance.deleteProduct(target.id, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Item "${target.name}" movido para a lixeira.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockZero,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _openMoveMasterCategoryDialog(ProductModel product) async {
    ProductModel target = product;
    if (product.hasSeparateSectorStocks) {
      final picked = await DuplicateStockDialog.pickSectorStock(
        context,
        consolidatedProduct: product,
        actionTitle: 'Alterar setor de qual estoque arquivado?',
      );
      if (picked == null || !mounted) return;
      target = picked;
    }
    if (!mounted) return;

    final selected = Set<String>.from(target.masterCategories);
    final allMasterCats = InventoryService.instance.masterCategories;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Alterar Setor do Arquivado',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...allMasterCats.map((mc) {
                    final isChecked = selected.contains(mc.id);
                    return CheckboxListTile(
                      dense: true,
                      secondary: Icon(mc.icon, color: mc.color, size: 20),
                      title: Text(mc.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            if (mc.id == 'outros') {
                              selected.clear();
                              selected.add('outros');
                            } else {
                              selected.add(mc.id);
                              selected.remove('outros');
                            }
                          } else {
                            selected.remove(mc.id);
                            if (selected.isEmpty) selected.add('outros');
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Salvar Alterações'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await InventoryService.instance.moveProductMasterCategories(
          productId: target.id,
          masterCategories: result.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.stockNormal,
              content: Text('Setor de "${target.name}" atualizado!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.stockZero,
              content: Text(e.toString().replaceAll('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Widget _buildSectorChip(
    String id,
    String label,
    IconData icon,
    int count, {
    Color? activeColor,
    required List<CategoryModel> allCategories,
    required List<ProductModel> archivedProducts,
  }) {
    final isSelected = _selectedMasterCategory == id;
    final Color chipColor = activeColor ?? const Color(0xFFD97706);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMasterCategory = id;
          if (_selectedCategoryId != null && id != 'todas') {
            final validSectorCats = InventoryService.instance.getCategoriesForSector(
              id,
              allCategories: allCategories,
              products: archivedProducts,
              onlyArchived: true,
            );
            if (!validSectorCats.any((c) => c.id == _selectedCategoryId)) {
              _selectedCategoryId = null;
              _selectedSubcategory = null;
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getAvailableSubcategories(
    List<CategoryModel> categories,
    List<ProductModel> archivedProducts,
    String? effectiveCategoryId,
  ) {
    if (effectiveCategoryId == null) return [];
    final selectedCat = categories.firstWhere(
      (c) => c.id == effectiveCategoryId,
      orElse: () => CategoryModel(id: effectiveCategoryId, name: ''),
    );
    final set = <String>{...selectedCat.subcategories};
    for (final p in archivedProducts) {
      if (_selectedMasterCategory != 'todas' &&
          !p.masterCategories.contains(_selectedMasterCategory)) {
        continue;
      }
      if (p.categoryIds.contains(effectiveCategoryId)) {
        for (final sub in p.subcategories) {
          if (sub.trim().isNotEmpty) set.add(sub.trim());
        }
        if (p.subcategory != null && p.subcategory!.trim().isNotEmpty) {
          set.add(p.subcategory!.trim());
        }
      }
    }
    set.addAll(_customSubcategories);
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<ProductModel> _filterAndSortArchived(
    List<ProductModel> archivedProducts,
    Map<String, String> categoryNameMap,
    String? effectiveCategoryId,
  ) {
    var list = archivedProducts.map((p) {
      final catNames = p.categoryIds
          .map((cid) => categoryNameMap[cid])
          .whereType<String>()
          .toList();
      return p.copyWith(categoryNames: catNames);
    }).toList();

    if (_selectedMasterCategory != 'todas') {
      list = list.where((p) => p.masterCategories.contains(_selectedMasterCategory)).toList();
    } else {
      list = ProductModel.consolidateForAllSectorsView(list);
    }

    if (effectiveCategoryId != null) {
      list = list.where((p) => p.categoryIds.contains(effectiveCategoryId)).toList();
    }

    if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
      list = list.where((p) =>
          p.subcategories.contains(_selectedSubcategory) ||
          p.subcategory == _selectedSubcategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      return ProductModel.filterAndSortByRelevance(list, _searchQuery);
    }

    switch (_selectedSort) {
      case SortOption.relevance:
      case SortOption.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.quantityAsc:
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case SortOption.quantityDesc:
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case SortOption.recentlyUpdated:
        list.sort((a, b) {
          final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        break;
    }
    return list;
  }

  Future<void> _handleManualSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await InventoryService.instance.syncAllWithSupabase();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.stockNormal,
          content: Text('Sincronizado com o Supabase com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.stockZero,
          content: Text('Erro ao sincronizar: ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return StreamBuilder<List<CategoryModel>>(
      stream: InventoryService.instance.streamCategories(),
      builder: (context, catSnap) {
        final categories = catSnap.data ?? InventoryService.instance.currentCategories;
        final categoryMap = {for (final c in categories) c.id: c.name};

        return Scaffold(
          appBar: (_isMobileSearchActive && isMobile)
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      setState(() {
                        _isMobileSearchActive = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  title: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      return TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _applySearchImmediately(),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Buscar nos arquivados...',
                          border: InputBorder.none,
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                )
              : AppBar(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.archive_outlined, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Produtos Arquivados',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (isMobile)
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar arquivados',
                        onPressed: () => setState(() => _isMobileSearchActive = true),
                      ),
                    AnimatedBuilder(
                      animation: CartService.instance,
                      builder: (context, _) {
                        final count = CartService.instance.itemCount;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined),
                              tooltip: 'Carrinho de Separação',
                              onPressed: _openCartModal,
                            ),
                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.stockZero,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.assessment_outlined, color: Color(0xFFD97706)),
                      tooltip: 'Gerar Relatório de Arquivados',
                      onPressed: () => SectorReportDialog.show(
                        context,
                        initialSectorId: _selectedMasterCategory,
                        isArchived: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.category_outlined),
                      tooltip: 'Gerenciar Categorias',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => CategoriesManageDialog(
                            initialSectorId: _selectedMasterCategory,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: 'Sincronizar com Supabase',
                      onPressed: _isSyncing ? null : _handleManualSync,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
          body: StreamBuilder<List<ProductModel>>(
            stream: InventoryService.instance.streamProducts(),
            builder: (context, prodSnap) {
              final allProducts = prodSnap.data ?? InventoryService.instance.currentProducts;
              final archivedProducts = allProducts.where((p) => p.isArchived).toList();

              final sectorCategories = InventoryService.instance.getCategoriesForSector(
                _selectedMasterCategory,
                allCategories: categories,
                products: archivedProducts,
                onlyArchived: true,
              );

              final effectiveCategoryId = (_selectedCategoryId != null &&
                      sectorCategories.any((c) => c.id == _selectedCategoryId))
                  ? _selectedCategoryId
                  : null;

              final filteredArchived = _filterAndSortArchived(
                archivedProducts,
                categoryMap,
                effectiveCategoryId,
              );

              final availableSubcategories = _getAvailableSubcategories(
                categories,
                archivedProducts,
                effectiveCategoryId,
              );

              return Column(
                children: [
                  // Barra de Setores dos Arquivados
                  StreamBuilder<List<MasterCategoryModel>>(
                    stream: InventoryService.instance.streamMasterCategories(),
                    builder: (context, masterSnap) {
                      final masterCats = masterSnap.data ?? InventoryService.instance.masterCategories;

                      return Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(16, isMobile ? 6 : 10, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildSectorChip(
                                      'todas',
                                      'Todos Arquivados',
                                      Icons.archive_outlined,
                                      archivedProducts.length,
                                      allCategories: categories,
                                      archivedProducts: archivedProducts,
                                    ),
                                    const SizedBox(width: 8),
                                    ...masterCats.map((mc) {
                                      final count = archivedProducts
                                          .where((p) => p.masterCategories.contains(mc.id))
                                          .length;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _buildSectorChip(
                                          mc.id,
                                          mc.name,
                                          mc.icon,
                                          count,
                                          activeColor: mc.color,
                                          allCategories: categories,
                                          archivedProducts: archivedProducts,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            if (isMobile) ...[
                              const SizedBox(width: 6),
                              PopupMenuButton<SortOption>(
                                tooltip: 'Ordenar arquivados',
                                initialValue: _selectedSort,
                                onSelected: (opt) => setState(() => _selectedSort = opt),
                                itemBuilder: (context) => SortOption.values.map((opt) {
                                  return PopupMenuItem<SortOption>(
                                    value: opt,
                                    child: Text(opt.label, style: GoogleFonts.inter(fontSize: 13)),
                                  );
                                }).toList(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.sort, size: 20, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  // Barra de Busca + Ordenação + Relatório no Desktop
                  if (!isMobile)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                return TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _applySearchImmediately(),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar item arquivado por nome, cód. interno ou P/N...',
                                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                                    suffixIcon: value.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: _clearSearch,
                                          )
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    isDense: true,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          PopupMenuButton<SortOption>(
                            tooltip: 'Ordenar arquivados',
                            initialValue: _selectedSort,
                            onSelected: (opt) => setState(() => _selectedSort = opt),
                            itemBuilder: (context) => SortOption.values.map((opt) {
                              return PopupMenuItem<SortOption>(
                                value: opt,
                                child: Text(opt.label, style: GoogleFonts.inter(fontSize: 13)),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sort, size: 18, color: AppColors.textPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ordenar',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: const Icon(Icons.assessment_outlined, size: 18),
                            label: Text(
                              'Relatório Arquivados',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => SectorReportDialog.show(
                              context,
                              initialSectorId: _selectedMasterCategory,
                              isArchived: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Barra de Categorias exclusiva do Setor selecionado
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CategoryFilterBar(
                      categories: sectorCategories,
                      selectedCategoryId: effectiveCategoryId,
                      selectedSubcategory: _selectedSubcategory,
                      availableSubcategories: availableSubcategories,
                      onSelectCategory: (id) {
                        setState(() {
                          _selectedCategoryId = id;
                          _selectedSubcategory = null;
                        });
                      },
                      onSelectSubcategory: (sub) {
                        setState(() => _selectedSubcategory = sub);
                      },
                      onAddSubcategory: (newSub) {
                        setState(() {
                          _customSubcategories.add(newSub);
                          _selectedSubcategory = newSub;
                        });
                      },
                      onManageCategories: () {
                        showDialog(
                          context: context,
                          builder: (_) => CategoriesManageDialog(
                            initialSectorId: _selectedMasterCategory,
                          ),
                        );
                      },
                      onBatchChangeCategory: () {
                        BatchChangeCategoryDialog.show(
                          context,
                          initialSourceCategoryId: effectiveCategoryId,
                          initialSectorId: _selectedMasterCategory,
                          onlyArchived: true,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Lista / Grade de Produtos Arquivados (totalmente editáveis)
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleManualSync,
                      child: filteredArchived.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.archive_outlined,
                                      size: 56,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Nenhum item arquivado para "$_searchQuery"'
                                          : 'Nenhum produto arquivado neste setor',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Produtos que saíram de uso mas permanecem em estoque aparecem aqui divididos por setor, podendo ser editados normalmente.',
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
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 900;
                                if (isWide) {
                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 460,
                                      mainAxisExtent: 280,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                    ),
                                    itemCount: filteredArchived.length,
                                    itemBuilder: (context, index) {
                                      final product = filteredArchived[index];
                                      return ProductCard(
                                        product: product,
                                        onEdit: () => _openEditProductDialog(product, categories),
                                        onDelete: () => _handleDeleteProduct(product),
                                        onOpenCart: _openCartModal,
                                        onMoveMasterCategory: () => _openMoveMasterCategoryDialog(product),
                                        onArchiveToggle: () => _handleUnarchiveProduct(product),
                                      );
                                    },
                                  );
                                }

                                return ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                                  itemCount: filteredArchived.length,
                                  itemBuilder: (context, index) {
                                    final product = filteredArchived[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: ProductCard(
                                        product: product,
                                        onEdit: () => _openEditProductDialog(product, categories),
                                        onDelete: () => _handleDeleteProduct(product),
                                        onOpenCart: _openCartModal,
                                        onMoveMasterCategory: () => _openMoveMasterCategoryDialog(product),
                                        onArchiveToggle: () => _handleUnarchiveProduct(product),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
