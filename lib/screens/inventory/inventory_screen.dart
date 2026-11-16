import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/lux_logo.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/services/cart_service.dart';
import '../../data/services/inventory_service.dart';
import '../admin/admin_panel_screen.dart';
import '../history/history_screen.dart';
import 'widgets/cart_modal.dart';
import 'widgets/categories_manage_dialog.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/product_card.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/pin_confirmation_dialog.dart';
import 'widgets/library_mode_screen.dart';

enum SortOption {
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
        content: const Text('Deseja realmente sair do sistema Luxpryme Stock?'),
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
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Gerenciar Categoria Mestre',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: Column(
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
                  'Selecione as categorias mestres para este produto:',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Eletrônica'),
                  subtitle: const Text('Componentes, semicondutores e PCBs'),
                  value: selected.contains('eletronica'),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.add('eletronica');
                        selected.remove('outros');
                      } else {
                        selected.remove('eletronica');
                        if (selected.isEmpty) selected.add('outros');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Produção'),
                  subtitle: const Text('Montagem de luminárias, gabinetes, baterias'),
                  value: selected.contains('producao'),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.add('producao');
                        selected.remove('outros');
                      } else {
                        selected.remove('producao');
                        if (selected.isEmpty) selected.add('outros');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Outros'),
                  subtitle: const Text('Insumos gerais, manutenção predial, civil'),
                  value: selected.contains('outros'),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.clear();
                        selected.add('outros');
                      } else {
                        selected.remove('outros');
                        if (selected.isEmpty) selected.add('eletronica');
                      }
                    });
                  },
                ),
              ],
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
              content: Text('Categoria mestre de "${product.name}" atualizada com sucesso!'),
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

  Widget _buildMasterCategoryChip(String id, String label, IconData icon, int count) {
    final isSelected = _selectedMasterCategory == id;
    Color activeColor;
    switch (id) {
      case 'eletronica':
        activeColor = const Color(0xFF2563EB);
        break;
      case 'producao':
        activeColor = const Color(0xFFD97706);
        break;
      case 'outros':
        activeColor = const Color(0xFF4B5563);
        break;
      default:
        activeColor = AppColors.primary;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMasterCategory = id;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
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

    // 3. Busca por Palavras Desordenadas (Nome, Código Interno, P/N, Subcategoria)
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => p.matchesSearch(_searchQuery)).toList();
    }

    // 3. Ordenação
    switch (_selectedSort) {
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

  @override
  Widget build(BuildContext context) {
    final userEmail = InventoryService.instance.currentUser?.email ??
        (InventoryService.instance.isLocalMode
            ? 'Tomas (Supervisor de Eletrônica)'
            : 'Operador');

    return StreamBuilder<List<CategoryModel>>(
      stream: InventoryService.instance.streamCategories(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        final categoryMap = {for (var c in categories) c.id: c.name};

        return Scaffold(
          appBar: AppBar(
            leading: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: LuxLogo(
                size: 34,
                variant: LuxLogoVariant.whiteOnBlue,
                showBrandName: false,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Setor de Eletrônica • $userEmail',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
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

              // Gerenciar Categorias
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
              // Barra de Seleção de Categoria Mestre
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMasterCategoryChip(
                        'todas',
                        'Todas',
                        Icons.dashboard_outlined,
                        rawProducts.length,
                      ),
                      const SizedBox(width: 8),
                      _buildMasterCategoryChip(
                        'eletronica',
                        'Eletrônica',
                        Icons.memory,
                        rawProducts.where((p) => p.isEletronica).length,
                      ),
                      const SizedBox(width: 8),
                      _buildMasterCategoryChip(
                        'producao',
                        'Produção',
                        Icons.precision_manufacturing_outlined,
                        rawProducts.where((p) => p.isProducao).length,
                      ),
                      const SizedBox(width: 8),
                      _buildMasterCategoryChip(
                        'outros',
                        'Outros',
                        Icons.inventory_2_outlined,
                        rawProducts.where((p) => p.isOutros).length,
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Barra de Busca e Ordenação
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

              // 2. Filtro Horizontal de Categorias (Suporta Múltiplas Categorias & Sub-categorias)
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddProductDialog(categories),
            icon: const Icon(Icons.add),
            label: Text(
              'Novo Item',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
