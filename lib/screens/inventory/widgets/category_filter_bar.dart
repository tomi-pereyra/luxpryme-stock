import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';

class CategoryFilterBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final String? selectedSubcategory;
  final List<String> availableSubcategories;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<String?> onSelectSubcategory;
  final VoidCallback onManageCategories;
  final ValueChanged<String>? onAddSubcategory;

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedSubcategory,
    required this.availableSubcategories,
    required this.onSelectCategory,
    required this.onSelectSubcategory,
    required this.onManageCategories,
    this.onAddSubcategory,
  });

  void _showAddSubcategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Nova Sub-categoria',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digite o nome da sub-categoria para filtrar e categorizar produtos:',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ex: Resistores, Bornes, Módulos...',
                ),
                onSubmitted: (val) {
                  final text = val.trim();
                  if (text.isNotEmpty) {
                    Navigator.of(ctx).pop();
                    onAddSubcategory?.call(text);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  onAddSubcategory?.call(text);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // CASO 1: UMA CATEGORIA ESTÁ SELECIONADA
    // Todas as outras somem, exibe a selecionada e ao lado suas sub-categorias.
    // Ao clicar na selecionada novamente, ela é desmarcada e todas reaparecem.
    // -------------------------------------------------------------------------
    if (selectedCategoryId != null) {
      final selectedCategory = categories.firstWhere(
        (c) => c.id == selectedCategoryId,
        orElse: () => CategoryModel(id: selectedCategoryId!, name: 'Categoria'),
      );

      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // Chip da Categoria Selecionada (Com 'X' para deselecionar e voltar todas)
            ActionChip(
              avatar: const Icon(Icons.close, size: 16, color: Colors.white),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCategory.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Clique p/ voltar',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              // Ao clicar na categoria já selecionada: DESELECIONA e volta todas!
              onPressed: () {
                onSelectCategory(null);
                onSelectSubcategory(null);
              },
            ),

            const SizedBox(width: 10),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8, color: AppColors.border),
            const SizedBox(width: 10),

            // Opção "Todas as Sub-categorias"
            ChoiceChip(
              label: Text(
                'Todas',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selectedSubcategory == null ? FontWeight.w700 : FontWeight.w500,
                  color: selectedSubcategory == null ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              selected: selectedSubcategory == null,
              onSelected: (_) => onSelectSubcategory(null),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primaryContainer,
              side: BorderSide(
                color: selectedSubcategory == null ? AppColors.primary : AppColors.border,
                width: selectedSubcategory == null ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),

            // Chips das Sub-categorias da Categoria Selecionada
            for (final sub in availableSubcategories) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selectedSubcategory == sub ? FontWeight.w700 : FontWeight.w500,
                    color: selectedSubcategory == sub ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                selected: selectedSubcategory == sub,
                onSelected: (selected) {
                  // Se clicou na já selecionada, desmarca voltando para Todas as subs
                  onSelectSubcategory(selected ? sub : null);
                },
                backgroundColor: Colors.white,
                selectedColor: AppColors.primaryContainer,
                side: BorderSide(
                  color: selectedSubcategory == sub ? AppColors.primary : AppColors.border,
                  width: selectedSubcategory == sub ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],

            const SizedBox(width: 8),
            // Botão para Adicionar Nova Sub-categoria
            ActionChip(
              avatar: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
              label: Text(
                'Nova Sub-cat',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              backgroundColor: AppColors.background,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: () => _showAddSubcategoryDialog(context),
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------------------
    // CASO 2: NENHUMA CATEGORIA SELECIONADA
    // Exibe "Todos" e todas as categorias principais lado a lado.
    // -------------------------------------------------------------------------
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 2, // 'Todos' + Categorias + Botão Gerenciar (+)
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Opção "Todos"
          if (index == 0) {
            return ChoiceChip(
              label: Text(
                'Todos',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              selected: true,
              onSelected: (_) => onSelectCategory(null),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primaryContainer,
              side: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }

          // Botão final para Adicionar/Gerenciar Categorias
          if (index == categories.length + 1) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: Text(
                'Nova Categoria',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.primaryLight, style: BorderStyle.solid),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: onManageCategories,
            );
          }

          // Chips das categorias normais
          final category = categories[index - 1];

          return ChoiceChip(
            label: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            selected: false,
            onSelected: (_) => onSelectCategory(category.id),
            backgroundColor: Colors.white,
            selectedColor: AppColors.primaryContainer,
            side: const BorderSide(
              color: AppColors.border,
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}
