import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/lux_logo.dart';
import '../../data/models/category_model.dart';
import '../../data/models/master_category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stock_conflict_model.dart';
import '../../data/services/cart_service.dart';
import '../../data/services/inventory_service.dart';
import '../admin/admin_panel_screen.dart';
import '../history/history_screen.dart';
import 'widgets/cart_modal.dart';
import 'widgets/categories_manage_dialog.dart';
import 'widgets/master_categories_manage_dialog.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/pin_confirmation_dialog.dart';
import 'widgets/library_mode_screen.dart';
import 'widgets/batch_add_master_category_dialog.dart';
import 'widgets/stock_conflict_dialog.dart';
import 'widgets/trash_bin_dialog.dart';

enum SortOption {
  relevance('Melhor Coincidência'),
  nameAsc('Nome (A - Z)'),
  nameDesc('Nome (Z - A)'),
  quantityAsc('Menor Estoque'),
  quantityDesc('Maior Estoque'),
  recentlyUpdated('Último Modificado');

  final String label;
  const SortOption(this.label);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedMasterCategory = 'todas';
  String? _selectedCategoryId;
  String? _selectedSubcategory;
  final Set<String> _customSubcategories = {};
  SortOption _selectedSort = SortOption.nameAsc;
  bool _isMobileSearchActive = false;

  bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCartModal() {
    showDialog(
      context: context,
      builder: (_) => const CartModal(),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Sessão'),
        content: const Text('Deseja realmente sair do sistema Estoque Luxpryme?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InventoryService.instance.signOut();
    }
  }

  void _openLibraryMode(
      List<CategoryModel> categories, List<ProductModel> products) {
    LibraryModeScreen.open(
      context,
      categories: categories,
      products: products,
      initialCategoryId: _selectedCategoryId,
      initialSubcategory: _selectedSubcategory,
      onSelect: (categoryId, subcategory) {
        setState(() {
          _selectedCategoryId = categoryId;
          _selectedSubcategory = subcategory;
        });
      },
    );
  }

  void _openAddProductDialog(List<CategoryModel> categories) {
    showDialog(
      context: context,
      builder: (_) => ProductFormDialog(
        categories: categories,
        initialCategoryId: _selectedCategoryId,
      ),
    );
  }

  void _openEditProductDialog(
      ProductModel product, List<CategoryModel> categories) {
    showDialog(
      context: context,
      builder: (_) => ProductFormDialog(
        productToEdit: product,
        categories: categories,
      ),
    );
  }

  Future<void> _handleDeleteProduct(ProductModel product) async {
    // Exige autenticação por PIN de 4 dígitos para eliminar produto
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirmar Exclusão',
      subtitle: 'Para eliminar o item do estoque, digite seu PIN de 4 dígitos:',
      itemName: product.name,
      actionLabel: 'Excluir Produto',
      actionColor: AppColors.stockZero,
      actionIcon: Icons.delete_forever,
    );

    if (pin == null) return; // Cancelado pelo usuário

    try {
      await InventoryService.instance.deleteProduct(product.id, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Item "${product.name}" excluído com sucesso.'),
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
    final selected = Set<String>.from(product.masterCategories);
    final allMasterCats = InventoryService.instance.masterCategories;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Gerenciar Setores',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (product.internalCode != null && product.internalCode!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cód. Int: ${product.internalCode}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Selecione os setores para este produto:',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...allMasterCats.map((mc) {
                    final isChecked = selected.contains(mc.id);
                    return CheckboxListTile(
                      dense: true,
                      secondary: Icon(mc.icon, color: mc.color, size: 20),
                      title: Text(mc.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: mc.description != null ? Text(mc.description!) : null,
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
          productId: product.id,
          masterCategories: result.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.stockNormal,
              content: Text('Setor de "${product.name}" atualizado com sucesso!'),
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

  Widget _buildMasterCategoryChip(
    String id,
    String label,
    IconData icon,
    int count, {
    Color? activeColor,
    VoidCallback? onLongPress,
  }) {
    final isSelected = _selectedMasterCategory == id;
    final Color chipColor = activeColor ??
        (id == 'eletronica'
            ? const Color(0xFF2563EB)
            : id == 'producao'
                ? const Color(0xFF059669)
                : id == 'outros'
                    ? const Color(0xFF64748B)
                    : AppColors.primary);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMasterCategory = id;
        });
      },
      onLongPress: onLongPress,
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
    List<ProductModel> rawProducts,
  ) {
    if (_selectedCategoryId == null) return [];
    final selectedCat = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => CategoryModel(id: _selectedCategoryId!, name: ''),
    );
    final set = <String>{...selectedCat.subcategories};
    for (final p in rawProducts) {
      if (p.categoryIds.contains(_selectedCategoryId)) {
        for (final sub in p.subcategories) {
          if (sub.trim().isNotEmpty) set.add(sub.trim());
        }
        if (p.subcategory != null && p.subcategory!.trim().isNotEmpty) {
          set.add(p.subcategory!.trim());
        }
      }
    }
    set.addAll(_customSubcategories);
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<ProductModel> _filterAndSortProducts(
    List<ProductModel> rawProducts,
    Map<String, String> categoryNameMap,
  ) {
    var list = rawProducts.map((p) {
      // Resolve os nomes de todas as categorias do produto
      final catNames = p.categoryIds
          .map((cid) => categoryNameMap[cid] ?? 'Outros')
          .toList();
      return p.copyWith(categoryNames: catNames);
    }).toList();

    // 0. Filtro por Categoria Mestre (Eletrônica / Produção / Outros / Todas)
    if (_selectedMasterCategory != 'todas') {
      list = list
          .where((p) => p.masterCategories.contains(_selectedMasterCategory))
          .toList();
    }

    // 1. Filtro por Categoria (Suporta múltiplas categorias por produto)
    if (_selectedCategoryId != null) {
      list = list
          .where((p) => p.categoryIds.contains(_selectedCategoryId))
          .toList();
    }

    // 2. Filtro por Sub-categoria (Suporta múltiplas sub-categorias)
    if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
      list = list.where((p) =>
          p.subcategories.contains(_selectedSubcategory) ||
          p.subcategory == _selectedSubcategory).toList();
    }

    // 3. Busca Inteligente com Ranqueamento de Relevância (Melhor Coincidência no Topo)
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => p.matchesSearch(_searchQuery)).toList();

      list.sort((a, b) {
        final scoreA = a.searchRelevance(_searchQuery);
        final scoreB = b.searchRelevance(_searchQuery);
        final scoreDiff = scoreB.compareTo(scoreA); // Maior pontuação primeiro
        if (scoreDiff != 0) return scoreDiff;

        // Desempate secundário baseado na ordenação selecionada
        switch (_selectedSort) {
          case SortOption.relevance:
          case SortOption.nameAsc:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case SortOption.nameDesc:
            return b.name.toLowerCase().compareTo(a.name.toLowerCase());
          case SortOption.quantityAsc:
            return a.quantity.compareTo(b.quantity);
          case SortOption.quantityDesc:
            return b.quantity.compareTo(a.quantity);
          case SortOption.recentlyUpdated:
            final dateA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
        }
      });
      return list;
    }

    // 4. Ordenação Padrão (quando não há texto na barra de busca)
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

  void _showSubcategoriesBottomSheet(
    List<CategoryModel> categories,
    List<ProductModel> rawProducts,
    String masterCatId,
    String masterCatName,
  ) {
    final prodsInMaster = masterCatId == 'todas'
        ? rawProducts
        : rawProducts.where((p) => p.masterCategories.contains(masterCatId)).toList();

    final subcats = <String>{};
    for (final p in prodsInMaster) {
      subcats.addAll(p.subcategories);
      if (p.subcategory != null && p.subcategory!.isNotEmpty) {
        subcats.add(p.subcategory!);
      }
    }
    final sortedSubcats = subcats.toList()..sort();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.folder_special_outlined,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Categorias do Setor "$masterCatName"',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: Text(
                    'Selecione uma categoria para filtrar:',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    (_selectedCategoryId == null && _selectedSubcategory == null)
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.primary,
                  ),
                  title: const Text('Todos os itens deste setor'),
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedSubcategory = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      ...categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        final count = prodsInMaster
                            .where((p) => p.categoryIds.contains(cat.id))
                            .length;
                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.folder_outlined,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          title: Text(cat.name,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          trailing: count > 0
                              ? Text('$count un',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = isSelected ? null : cat.id;
                              _selectedSubcategory = null;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      if (sortedSubcats.isNotEmpty) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          child: Text(
                            'Sub-categorias:',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary),
                          ),
                        ),
                        ...sortedSubcats.map((sub) {
                          final isSelected = _selectedSubcategory == sub;
                          final count = prodsInMaster
                              .where((p) =>
                                  p.subcategories.contains(sub) ||
                                  p.subcategory == sub)
                              .length;
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.label_outline,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 18,
                            ),
                            title: Text(sub,
                                style: GoogleFonts.inter(fontSize: 13)),
                            trailing: Text('$count un',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            onTap: () {
                              setState(() {
                                _selectedSubcategory = isSelected ? null : sub;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBottomRightMenu(
    List<CategoryModel> categories,
    List<ProductModel> rawProducts,
    List<MasterCategoryModel> masterCats,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.apps, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Menu de Ações',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                // 1. + Itens
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_add, color: AppColors.primary),
                  ),
                  title: Text(
                    '+ Itens',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Buscar e adicionar múltiplos produtos ao setor',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    BatchAddMasterCategoryDialog.show(
                      context,
                      initialMasterCategoryId: _selectedMasterCategory,
                      masterCategories: masterCats,
                      mode: BatchItemMode.add,
                    );
                  },
                ),
                const Divider(height: 1),

                // 2. - Itens
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_remove, color: AppColors.stockZero),
                  ),
                  title: Text(
                    '- Itens',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.stockZero),
                  ),
                  subtitle: Text(
                    'Buscar e desvincular produtos de um setor',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    BatchAddMasterCategoryDialog.show(
                      context,
                      initialMasterCategoryId: _selectedMasterCategory,
                      masterCategories: masterCats,
                      mode: BatchItemMode.remove,
                    );
                  },
                ),
                const Divider(height: 1),

                // 2. Novo Item
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_outlined,
                        color: AppColors.stockNormal),
                  ),
                  title: Text(
                    'Novo Item',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Cadastrar um novo produto ou componente',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAddProductDialog(categories);
                  },
                ),
                const Divider(height: 1),

                // 3. Categorias de Estoque
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.category_outlined,
                        color: Color(0xFF7C3AED)),
                  ),
                  title: Text(
                    'Categorias de Estoque',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Gerenciar categorias e tipos comuns',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => const CategoriesManageDialog(),
                    );
                  },
                ),
                const Divider(height: 1),

                // 4. Biblioteca de Modelos
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_tree_outlined,
                        color: Color(0xFFD97706)),
                  ),
                  title: Text(
                    'Biblioteca de Modelos',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Visualizar catálogo organizado em modelos',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openLibraryMode(categories, rawProducts);
                  },
                ),
                const Divider(height: 1),

                // 5. Lixeira de Produtos
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restore_from_trash,
                        color: Color(0xFFD97706)),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Lixeira de Produtos',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<List<ProductModel>>(
                        stream: InventoryService.instance.streamTrashProducts(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Visualizar e recuperar produtos excluídos',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    TrashBinDialog.show(context);
                  },
                ),
                const Divider(height: 1),

                // 6. Sobre o Sistema
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: AppColors.textSecondary),
                  ),
                  title: Text(
                    'Sobre o Aplicativo',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${AppConstants.appDeveloperRole}: ${AppConstants.appDeveloper}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAboutDialog();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const LuxLogo(size: 32, variant: LuxLogoVariant.whiteOnBlue, showBrandName: false),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appTagline,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Desenvolvedor e Administrador:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tomas Pereyra',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Versão: ${AppConstants.appVersion}',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Empresa: Luxpryme Indústria Eletrônica',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return StreamBuilder<List<CategoryModel>>(
      stream: InventoryService.instance.streamCategories(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        final categoryMap = {for (var c in categories) c.id: c.name};

        return Scaffold(
          appBar: (_isMobileSearchActive && isMobile)
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _isMobileSearchActive = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  title: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, código, P/N...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                )
              : AppBar(
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: LuxLogo(
                      size: 34,
                      variant: LuxLogoVariant.whiteOnBlue,
                      showBrandName: false,
                    ),
                  ),
                  title: isMobile
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${AppConstants.appDeveloperRole}: ${AppConstants.appDeveloper}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                  actions: [
                    // Lupa de busca no menu superior para versão mobile
                    if (isMobile)
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar componentes',
                        onPressed: () {
                          setState(() {
                            _isMobileSearchActive = true;
                          });
                        },
                      ),

                    // Botão Carrinho de Separação com Badge
                    AnimatedBuilder(
                      animation: CartService.instance,
                      builder: (context, _) {
                        final count = CartService.instance.itemCount;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined),
                              tooltip: 'Carrinho de Separação (Finalizar com PIN)',
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
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$count',
                                    textAlign: TextAlign.center,
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

                    // Botão Histórico e Relatórios
                    IconButton(
                      icon: const Icon(Icons.history_outlined),
                      tooltip: 'Histórico & Relatórios de Estoque',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(categories: categories),
                          ),
                        );
                      },
                    ),

                    // Botão Lixeira de Produtos com Badge
                    StreamBuilder<List<ProductModel>>(
                      stream: InventoryService.instance.streamTrashProducts(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Lixeira de Produtos Excluídos',
                              onPressed: () => TrashBinDialog.show(context),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD97706),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$count',
                                    textAlign: TextAlign.center,
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

                    // Botão Painel do Administrador (Exclusivo Windows e restrito para tomibr20@gmail.com)
                    if (isWindowsDesktop && InventoryService.instance.isAdminUser) ...[
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
                        tooltip: 'Painel do Administrador (Exclusivo tomibr20@gmail.com)',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen(),
                            ),
                          );
                        },
                      ),
                    ],

                    // Gerenciar Categorias (Apenas no desktop; no mobile fica no menu inferior direito)
                    if (!isMobile)
                      IconButton(
                        icon: const Icon(Icons.category_outlined),
                        tooltip: 'Gerenciar Categorias',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CategoriesManageDialog(),
                          );
                        },
                      ),

                    // Sincronizar Estoque
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Sincronizar Estoque',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await InventoryService.instance.fetchProducts();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Estoque sincronizado com sucesso.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Erro ao atualizar: $e')),
                          );
                        }
                      },
                    ),

                    // Logout
                    IconButton(
                      icon: const Icon(Icons.logout_outlined, color: AppColors.stockZero),
                      tooltip: 'Sair da conta',
                      onPressed: _handleLogout,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: StreamBuilder<List<ProductModel>>(
            stream: InventoryService.instance.streamProducts(),
            builder: (context, prodSnapshot) {
              final rawProducts = prodSnapshot.data ?? [];
              final filteredProducts =
                  _filterAndSortProducts(rawProducts, categoryMap);
              final availableSubcategories =
                  _getAvailableSubcategories(categories, rawProducts);

              return Column(
                children: [
                  // Banner de Alerta para Conflitos de Estoque (Saldo Negativo)
                  StreamBuilder<List<StockConflictModel>>(
                    stream: InventoryService.instance.streamStockConflicts(),
                    builder: (context, conflictSnapshot) {
                      final conflicts =
                          conflictSnapshot.data ?? InventoryService.instance.activeConflicts;
                      if (conflicts.isEmpty) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.stockZero, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Conflito de Estoque: ${conflicts.length} item(ns) com saldo negativo',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.stockZero,
                                    ),
                                  ),
                                  Text(
                                    'Retiradas simultâneas geraram déficit. Clique para corrigir.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.stockZero,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => StockConflictDialog.show(context, conflicts),
                              child: Text(
                                'Resolver',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

              // Barra de Seleção de Categoria Mestre Dinâmica
              StreamBuilder<List<MasterCategoryModel>>(
                stream: InventoryService.instance.streamMasterCategories(),
                builder: (context, masterSnapshot) {
                  final masterCats = masterSnapshot.data ?? InventoryService.instance.masterCategories;

                  return Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(16, isMobile ? 6 : 10, isMobile ? 12 : 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildMasterCategoryChip(
                                  'todas',
                                  'Todas',
                                  Icons.dashboard_outlined,
                                  rawProducts.length,
                                  onLongPress: isMobile
                                      ? () => _showSubcategoriesBottomSheet(
                                            categories,
                                            rawProducts,
                                            'todas',
                                            'Todas',
                                          )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                ...masterCats.map((mc) {
                                  final count = rawProducts
                                      .where((p) => p.masterCategories.contains(mc.id))
                                      .length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildMasterCategoryChip(
                                      mc.id,
                                      mc.name,
                                      mc.icon,
                                      count,
                                      activeColor: mc.color,
                                      onLongPress: isMobile
                                          ? () => _showSubcategoriesBottomSheet(
                                                categories,
                                                rawProducts,
                                                mc.id,
                                                mc.name,
                                              )
                                          : null,
                                    ),
                                  );
                                }),
                                // Botão Gerenciar Categorias Mestres (PIN Mestre)
                                InkWell(
                                  onTap: () => MasterCategoriesManageDialog.show(context),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.tune, size: 16, color: AppColors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Gerenciar',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // No celular: botão compacto de ordenação no canto direito da barra de categorias mestres
                        if (isMobile) ...[
                          const SizedBox(width: 6),
                          PopupMenuButton<SortOption>(
                            tooltip: 'Ordenar produtos',
                            initialValue: _selectedSort,
                            onSelected: (option) {
                              setState(() => _selectedSort = option);
                            },
                            itemBuilder: (context) => SortOption.values.map((opt) {
                              return PopupMenuItem<SortOption>(
                                value: opt,
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedSort == opt
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 16,
                                      color: _selectedSort == opt
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      opt.label,
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                  ],
                                ),
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

              // Chip indicando filtro de categoria comum ativo no mobile
              if (isMobile && (_selectedCategoryId != null || _selectedSubcategory != null))
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_alt, size: 14, color: AppColors.primaryDark),
                            const SizedBox(width: 4),
                            Text(
                              'Filtro: ${_selectedSubcategory ?? categoryMap[_selectedCategoryId] ?? ""}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _selectedSubcategory = null;
                                });
                              },
                              child: const Icon(Icons.close, size: 14, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. Barra de Busca e Ordenação (Apenas versão Desktop)
              if (!isMobile)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      // Campo de Busca inteligente
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nome, cód. interno ou part number...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Menu de Ordenação
                      PopupMenuButton<SortOption>(
                        tooltip: 'Ordenar produtos',
                        initialValue: _selectedSort,
                        onSelected: (option) {
                          setState(() => _selectedSort = option);
                        },
                        itemBuilder: (context) => SortOption.values.map((opt) {
                          return PopupMenuItem<SortOption>(
                            value: opt,
                            child: Row(
                              children: [
                                Icon(
                                  _selectedSort == opt
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 16,
                                  color: _selectedSort == opt
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  opt.label,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ],
                            ),
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
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão Modo Biblioteca (Menu Desdobrável)
                      InkWell(
                        onTap: () => _openLibraryMode(categories, rawProducts),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            border: Border.all(color: AppColors.primaryLight),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree_outlined, size: 18, color: AppColors.primaryDark),
                              const SizedBox(width: 6),
                              Text(
                                'Biblioteca',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Filtro Horizontal de Categorias (Apenas versão Desktop)
              if (!isMobile)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CategoryFilterBar(
                    categories: categories,
                    selectedCategoryId: _selectedCategoryId,
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
                        builder: (_) => const CategoriesManageDialog(),
                      );
                    },
                  ),
                ),

              const Divider(height: 1, color: AppColors.border),

              // 3. Lista em Tempo Real de Produtos
              Expanded(
                child: prodSnapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => InventoryService.instance.fetchProducts(),
                        child: filteredProducts.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isNotEmpty
                                        ? Icons.search_off_outlined
                                        : Icons.inventory_2_outlined,
                                    size: 56,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Nenhum item encontrado para "$_searchQuery"'
                                        : 'Nenhum produto cadastrado',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tente buscar pelo nome, código interno ou part number.',
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
                              // Em telas largas (desktop tela cheia / telas >= 900px), organiza em grade
                              // com largura máxima controlada por card para evitar que ocupe a largura inteira
                              final isWide = constraints.maxWidth >= 900;
                              if (isWide) {
                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 460,
                                    mainAxisExtent: 280,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    return ProductCard(
                                      product: product,
                                      onEdit: () => _openEditProductDialog(
                                          product, categories),
                                      onDelete: () =>
                                          _handleDeleteProduct(product),
                                      onOpenCart: _openCartModal,
                                      onMoveMasterCategory: () =>
                                          _openMoveMasterCategoryDialog(product),
                                    );
                                  },
                                );
                              }

                              return ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ProductCard(
                                      product: product,
                                      onEdit: () => _openEditProductDialog(
                                          product, categories),
                                      onDelete: () =>
                                          _handleDeleteProduct(product),
                                      onOpenCart: _openCartModal,
                                      onMoveMasterCategory: () =>
                                          _openMoveMasterCategoryDialog(product),
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
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openBottomRightMenu(
              categories,
              InventoryService.instance.currentProducts,
              InventoryService.instance.masterCategories,
            ),
            tooltip: 'Menu de Ações (+ Itens, Novo Item, Categorias, Biblioteca)',
            child: const Icon(Icons.menu),
          ),
        );
      },
    );
  }
}
