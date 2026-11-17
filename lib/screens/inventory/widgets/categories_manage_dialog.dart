import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/services/inventory_service.dart';
import 'master_categories_manage_dialog.dart';

class CategoriesManageDialog extends StatefulWidget {
  const CategoriesManageDialog({super.key});

  @override
  State<CategoriesManageDialog> createState() => _CategoriesManageDialogState();
}

class _CategoriesManageDialogState extends State<CategoriesManageDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe o nome da categoria.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      await InventoryService.instance.createCategory(
        name: name,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      );
      _nameController.clear();
      _descController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Categoria "$name" criada com sucesso!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _handleDelete(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: Text(
          'Deseja realmente remover a categoria "${category.name}"?\nIsso só será permitido se não houver produtos vinculados a ela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stockZero),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await InventoryService.instance.deleteCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Categoria "${category.name}" removida com sucesso!'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Responsivo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.category_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Categorias de Estoque',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 15),
                  label: Text(
                    'Gerenciar Categorias Mestres',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    MasterCategoriesManageDialog.show(context);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Formulário de Nova Categoria
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Adicionar Nova Categoria / Tipo',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Nome (ex: Cabos e Chicotes, Dissipadores)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        hintText: 'Descrição breve (opcional)',
                        isDense: true,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: _isCreating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add, size: 16),
                        label: Text(
                          _isCreating ? 'Adicionando...' : 'Criar Categoria',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isCreating ? null : _handleCreate,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Categorias Atuais (Sincronizado em Tempo Real):',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Lista em tempo real das categorias
              Expanded(
                child: StreamBuilder<List<CategoryModel>>(
                  stream: InventoryService.instance.streamCategories(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final categories = snapshot.data ?? [];
                    if (categories.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhuma categoria encontrada.',
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryContainer,
                            child: Icon(Icons.label_outline, size: 16, color: AppColors.primary),
                          ),
                          title: Text(
                            cat.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: cat.description != null && cat.description!.isNotEmpty
                              ? Text(
                                  cat.description!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.stockZero),
                            tooltip: 'Excluir categoria',
                            onPressed: () => _handleDelete(cat),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
