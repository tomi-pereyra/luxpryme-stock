import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'master_categories_manage_dialog.dart';

class CategoriesManageDialog extends StatefulWidget {
  final String? initialSectorId;

  const CategoriesManageDialog({
    super.key,
    this.initialSectorId,
  });

  @override
  State<CategoriesManageDialog> createState() => _CategoriesManageDialogState();
}

class _CategoriesManageDialogState extends State<CategoriesManageDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  late Set<String> _selectedNewSectors;
  late bool _filterByCurrentSector;
  bool _isCreating = false;
  String? _errorMessage;

  bool get _hasSpecificSector =>
      widget.initialSectorId != null &&
      widget.initialSectorId!.trim().isNotEmpty &&
      widget.initialSectorId!.toLowerCase() != 'todas';

  @override
  void initState() {
    super.initState();
    _filterByCurrentSector = _hasSpecificSector;
    if (_hasSpecificSector) {
      _selectedNewSectors = {widget.initialSectorId!.toLowerCase()};
    } else {
      final masterCats = InventoryService.instance.masterCategories;
      _selectedNewSectors = masterCats.isNotEmpty ? {masterCats.first.id} : {'eletronica'};
    }
  }

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
        masterCategories: _selectedNewSectors.toList(),
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

  Future<void> _openEditCategoryDialog(
    CategoryModel category,
    List<MasterCategoryModel> allSectors,
    List<ProductModel> allProducts,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: category.name);
    final descCtrl = TextEditingController(text: category.description ?? '');

    // Descobre setores onde já é usada ou onde foi registrada
    final initialSectors = <String>{...category.masterCategories};
    for (final p in allProducts) {
      if (p.categoryIds.contains(category.id)) {
        initialSectors.addAll(p.masterCategories);
      }
    }
    String? editError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Editar Categoria',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (editError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.stockZero.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          editError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero),
                        ),
                      ),
                    ],
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Categoria *',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Setores vinculados a esta categoria:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allSectors.map((mc) {
                        final isSelected = initialSectors.contains(mc.id);
                        return FilterChip(
                          label: Text(mc.name, style: GoogleFonts.inter(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: mc.color.withValues(alpha: 0.15),
                          checkmarkColor: mc.color,
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                initialSectors.add(mc.id);
                              } else {
                                initialSectors.remove(mc.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Salvar'),
                onPressed: () async {
                  final newName = nameCtrl.text.trim();
                  if (newName.isEmpty) {
                    setDialogState(() => editError = 'Informe o nome da categoria.');
                    return;
                  }
                  try {
                    await InventoryService.instance.updateCategory(
                      id: category.id,
                      name: newName,
                      description: descCtrl.text.trim(),
                      masterCategories: initialSectors.toList(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.stockNormal,
                        content: Text('Categoria renomeada/atualizada para "$newName"!'),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() {
                      editError = e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(CategoryModel category, int linkedProductCount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Categoria?'),
        content: Text(
          linkedProductCount > 0
              ? 'Deseja realmente excluir a categoria "${category.name}"?\n\n'
                  'Existem $linkedProductCount produto(s) com esta categoria. '
                  'Ela será removida automaticamente desses produtos sem apagá-los do estoque.'
              : 'Deseja realmente remover a categoria "${category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stockZero),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir Categoria'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final unlinked = await InventoryService.instance.deleteCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              unlinked > 0
                  ? 'Categoria "${category.name}" excluída e desvinculada de $unlinked produto(s)!'
                  : 'Categoria "${category.name}" removida com sucesso!',
            ),
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
    final allSectors = InventoryService.instance.masterCategories;
    final activeSectorName = _hasSpecificSector
        ? InventoryService.instance.getMasterCategoryName(widget.initialSectorId!)
        : 'Todos os Setores';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.dashboard_customize_outlined, size: 15),
                    label: Text(
                      'Gerenciar Setores',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      MasterCategoriesManageDialog.show(context);
                    },
                  ),
                  if (_hasSpecificSector)
                    FilterChip(
                      label: Text(
                        _filterByCurrentSector
                            ? 'Setor: $activeSectorName'
                            : 'Exibindo todos os setores',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      selected: _filterByCurrentSector,
                      onSelected: (val) => setState(() => _filterByCurrentSector = val),
                      selectedColor: AppColors.primaryContainer,
                      checkmarkColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),

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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Setor:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        ...allSectors.map((mc) {
                          final sel = _selectedNewSectors.contains(mc.id);
                          return FilterChip(
                            label: Text(mc.name, style: GoogleFonts.inter(fontSize: 11)),
                            selected: sel,
                            visualDensity: VisualDensity.compact,
                            selectedColor: mc.color.withValues(alpha: 0.15),
                            checkmarkColor: mc.color,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedNewSectors.add(mc.id);
                                } else if (_selectedNewSectors.length > 1) {
                                  _selectedNewSectors.remove(mc.id);
                                }
                              });
                            },
                          );
                        }),
                      ],
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

              const SizedBox(height: 14),
              Text(
                _filterByCurrentSector && _hasSpecificSector
                    ? 'Categorias do Setor "$activeSectorName":'
                    : 'Categorias Cadastradas:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),

              // Lista em tempo real das categorias
              Expanded(
                child: StreamBuilder<List<ProductModel>>(
                  stream: InventoryService.instance.streamProducts(),
                  builder: (context, prodSnap) {
                    final allProducts = prodSnap.data ?? InventoryService.instance.currentProducts;

                    return StreamBuilder<List<CategoryModel>>(
                      stream: InventoryService.instance.streamCategories(),
                      builder: (context, snapshot) {
                        final allCategories = snapshot.data ?? InventoryService.instance.currentCategories;
                        final categories = (_filterByCurrentSector && _hasSpecificSector)
                            ? InventoryService.instance.getCategoriesForSector(
                                widget.initialSectorId!,
                                allCategories: allCategories,
                                products: allProducts,
                              )
                            : allCategories;

                        if (categories.isEmpty) {
                          return Center(
                            child: Text(
                              _filterByCurrentSector && _hasSpecificSector
                                  ? 'Nenhuma categoria cadastrada no setor "$activeSectorName".'
                                  : 'Nenhuma categoria encontrada.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppColors.textMuted),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final linkedCount = allProducts
                                .where((p) => p.categoryIds.contains(cat.id))
                                .length;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: const CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryContainer,
                                child: Icon(Icons.label_outline, size: 16, color: AppColors.primary),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (linkedCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        '$linkedCount item(ns)',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ),
                                ],
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                    tooltip: 'Renomear / editar categoria',
                                    onPressed: () => _openEditCategoryDialog(cat, allSectors, allProducts),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.stockZero),
                                    tooltip: 'Excluir categoria',
                                    onPressed: () => _handleDelete(cat, linkedCount),
                                  ),
                                ],
                              ),
                            );
                          },
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
