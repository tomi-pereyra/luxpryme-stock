import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';

class CategoryFilterBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelectCategory;
  final VoidCallback onManageCategories;

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onManageCategories,
  });

  @override
  Widget build(BuildContext context) {
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
            final isSelected = selectedCategoryId == null;
            return ChoiceChip(
              label: Text(
                'Todos',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelectCategory(null),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primaryContainer,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
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

          // Chips das categorias
          final category = categories[index - 1];
          final isSelected = selectedCategoryId == category.id;

          return ChoiceChip(
            label: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelectCategory(category.id),
            backgroundColor: Colors.white,
            selectedColor: AppColors.primaryContainer,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
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
