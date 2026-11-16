import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';

class LibraryModeScreen extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final String? initialCategoryId;
  final String? initialSubcategory;
  final void Function(String? categoryId, String? subcategory) onSelect;

  const LibraryModeScreen({
    super.key,
    required this.categories,
    required this.products,
    this.initialCategoryId,
    this.initialSubcategory,
    required this.onSelect,
  });

  /// Abre o Modo Biblioteca. No celular ocupa a tela inteira (fullscreen).
  static Future<void> open(
    BuildContext context, {
    required List<CategoryModel> categories,
    required List<ProductModel> products,
    String? initialCategoryId,
    String? initialSubcategory,
    required void Function(String? categoryId, String? subcategory) onSelect,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LibraryModeScreen(
          categories: categories,
          products: products,
          initialCategoryId: initialCategoryId,
          initialSubcategory: initialSubcategory,
          onSelect: onSelect,
        ),
      ),
    );
  }

  @override
  State<LibraryModeScreen> createState() => _LibraryModeScreenState();
}

class _LibraryModeScreenState extends State<LibraryModeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      _expandedCategoryIds.add(widget.initialCategoryId!);
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Calcula quantos produtos pertencem a uma categoria
  int _countProductsInCategory(String categoryId) {
    return widget.products.where((p) => p.categoryIds.contains(categoryId)).length;
  }

  /// Calcula quantos produtos pertencem a uma categoria + subcategoria
  int _countProductsInSubcategory(String categoryId, String subcategory) {
    final subLower = subcategory.trim().toLowerCase();
    return widget.products.where((p) {
      if (!p.categoryIds.contains(categoryId)) return false;
      return p.subcategories.any((s) => s.trim().toLowerCase() == subLower) ||
          (p.subcategory != null && p.subcategory!.trim().toLowerCase() == subLower);
    }).length;
  }

  /// Coleta todas as sub-categorias conhecidas de uma categoria
  List<String> _getSubcategoriesForCategory(CategoryModel cat) {
    final set = <String>{...cat.subcategories};
    for (final p in widget.products) {
      if (p.categoryIds.contains(cat.id)) {
        for (final s in p.subcategories) {
          if (s.trim().isNotEmpty) set.add(s.trim());
        }
        if (p.subcategory != null && p.subcategory!.trim().isNotEmpty) {
          set.add(p.subcategory!.trim());
        }
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _handleSelectCategory(String categoryId) {
    widget.onSelect(categoryId, null);
    Navigator.of(context).pop();
  }

  void _handleSelectSubcategory(String categoryId, String subcategory) {
    widget.onSelect(categoryId, subcategory);
    Navigator.of(context).pop();
  }

  void _handleShowAll() {
    widget.onSelect(null, null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final totalProducts = widget.products.length;
    final totalCategories = widget.categories.length;

    // Filtra categorias e sub-categorias pela busca
    final filteredCategories = widget.categories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      final catNameMatch = cat.name.toLowerCase().contains(_searchQuery);
      if (catNameMatch) return true;

      final subs = _getSubcategoriesForCategory(cat);
      final subMatch = subs.any((s) => s.toLowerCase().contains(_searchQuery));
      return subMatch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo Biblioteca',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Explorador hierárquico de Categorias e Sub-categorias',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _handleShowAll,
            icon: const Icon(Icons.all_inclusive, size: 16),
            label: Text(
              'Ver Tudo',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Barra de Busca e Estatísticas
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar biblioteca por categoria ou sub-categoria...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Resumo rápido em cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.category_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '$totalCategories Categorias',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.stockNormal),
                            const SizedBox(width: 8),
                            Text(
                              '$totalProducts Itens em Estoque',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // 2. Lista Desdobrável / Hierárquica de Categorias e Sub-categorias
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_off_outlined, size: 54, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma categoria encontrada para "$_searchQuery"',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final cat = filteredCategories[index];
                      final catProductsCount = _countProductsInCategory(cat.id);
                      final subcategories = _getSubcategoriesForCategory(cat);
                      final isExpanded = _expandedCategoryIds.contains(cat.id) || _searchQuery.isNotEmpty;
                      final isSelectedCategory = widget.initialCategoryId == cat.id && widget.initialSubcategory == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelectedCategory ? AppColors.primary : AppColors.border,
                            width: isSelectedCategory ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: PageStorageKey('cat_expansion_${cat.id}'),
                              initiallyExpanded: isExpanded,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.folder_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$catProductsCount itens',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                subcategories.isEmpty
                                    ? 'Sem sub-categorias'
                                    : '${subcategories.length} sub-categoria${subcategories.length > 1 ? "s" : ""}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expandedCategoryIds.add(cat.id);
                                  } else {
                                    _expandedCategoryIds.remove(cat.id);
                                  }
                                });
                              },
                              children: [
                                const Divider(height: 1, color: AppColors.border),

                                // Ação para selecionar a categoria inteira
                                InkWell(
                                  onTap: () => _handleSelectCategory(cat.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    color: isSelectedCategory
                                        ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                        : Colors.white,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.select_all,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Ver todos os produtos desta categoria (${cat.name})',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),

                                const Divider(height: 1, color: AppColors.border),

                                // Lista das Sub-categorias desdobradas
                                if (subcategories.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Text(
                                      'Nenhuma sub-categoria vinculada.',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  )
                                else
                                  ...subcategories.map((sub) {
                                    final subCount = _countProductsInSubcategory(cat.id, sub);
                                    final isSelectedSub = widget.initialCategoryId == cat.id &&
                                        widget.initialSubcategory == sub;

                                    return InkWell(
                                      onTap: () => _handleSelectSubcategory(cat.id, sub),
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
                                        decoration: BoxDecoration(
                                          color: isSelectedSub
                                              ? const Color(0xFFEEF2FF)
                                              : Colors.white,
                                          border: const Border(
                                            bottom: BorderSide(color: Color(0xFFF1F5F9)),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 16,
                                              color: Color(0xFF4F46E5),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                sub,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: isSelectedSub ? FontWeight.w700 : FontWeight.w500,
                                                  color: isSelectedSub
                                                      ? const Color(0xFF4338CA)
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelectedSub
                                                    ? const Color(0xFFC7D2FE)
                                                    : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelectedSub
                                                      ? const Color(0xFF818CF8)
                                                      : AppColors.border,
                                                ),
                                              ),
                                              child: Text(
                                                '$subCount itens',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelectedSub
                                                      ? const Color(0xFF3730A3)
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 16,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
