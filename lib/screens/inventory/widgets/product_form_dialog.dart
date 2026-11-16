import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'categories_manage_dialog.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductModel? productToEdit;
  final List<CategoryModel> categories;
  final String? initialCategoryId;

  const ProductFormDialog({
    super.key,
    this.productToEdit,
    required this.categories,
    this.initialCategoryId,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _internalCodeController;
  late TextEditingController _manufacturerCodeController;
  late TextEditingController _quantityController;
  late TextEditingController _minQuantityController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  late Set<String> _selectedCategoryIds;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _nameController = TextEditingController(text: p?.name ?? '');
    _internalCodeController =
        TextEditingController(text: p?.internalCode ?? p?.code ?? '');
    _manufacturerCodeController =
        TextEditingController(text: p?.manufacturerCode ?? '');
    _quantityController =
        TextEditingController(text: (p?.quantity ?? 0).toString());
    _minQuantityController =
        TextEditingController(text: (p?.minQuantity ?? 10).toString());
    _locationController = TextEditingController(text: p?.location ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');

    // Inicializa categorias selecionadas
    if (p != null && p.categoryIds.isNotEmpty) {
      _selectedCategoryIds = Set.from(p.categoryIds);
    } else if (widget.initialCategoryId != null) {
      _selectedCategoryIds = {widget.initialCategoryId!};
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryIds = {widget.categories.first.id};
    } else {
      _selectedCategoryIds = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _internalCodeController.dispose();
    _manufacturerCodeController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione ao menos uma categoria para o item.';
      });
      return;
    }

    final int qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final int minQty = int.tryParse(_minQuantityController.text.trim()) ?? 10;

    if (qty < 0) {
      setState(() {
        _errorMessage = 'A quantidade não pode ser negativa.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categoryList = _selectedCategoryIds.toList();
      final categoryNameList = widget.categories
          .where((c) => _selectedCategoryIds.contains(c.id))
          .map((c) => c.name)
          .toList();

      final internalCode = _internalCodeController.text.trim().isEmpty
          ? null
          : _internalCodeController.text.trim();
      final manufacturerCode = _manufacturerCodeController.text.trim().isEmpty
          ? null
          : _manufacturerCodeController.text.trim();

      final product = ProductModel(
        id: widget.productToEdit?.id ?? '',
        name: _nameController.text.trim(),
        code: internalCode ?? manufacturerCode,
        internalCode: internalCode,
        manufacturerCode: manufacturerCode,
        categoryIds: categoryList,
        categoryNames: categoryNameList,
        quantity: qty,
        minQuantity: minQty,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (isEditing) {
        await InventoryService.instance.updateProduct(product);
      } else {
        await InventoryService.instance.createProduct(product);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              isEditing ? 'Item atualizado com sucesso!' : 'Novo item adicionado ao estoque!',
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note : Icons.add_box_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Produto' : 'Cadastrar Novo Produto',
                      style: GoogleFonts.inter(
                        fontSize: 18,
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
            ),
            const Divider(height: 1, color: AppColors.border),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Nome do Produto
                      Text(
                        'Nome do Componente ou Placa *',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Resistor 10k 1% 0805 ou PCB Controladora V2',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Informe o nome do item';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Códigos (Interno e Fabricante)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Código Interno (Cód. Int)',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _internalCodeController,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: 1001, 1002',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Código Fabricante / P/N',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _manufacturerCodeController,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: PN-1001, COMP-A',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Múltiplas Categorias
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Categorias (Pode marcar mais de uma) *',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          InkWell(
                            onTap: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => const CategoriesManageDialog(),
                              );
                            },
                            child: Text(
                              '+ Gerenciar categorias',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.categories.map((cat) {
                            final isSelected = _selectedCategoryIds.contains(cat.id);
                            return FilterChip(
                              label: Text(
                                cat.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primaryContainer,
                              checkmarkColor: AppColors.primary,
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(cat.id);
                                  } else {
                                    if (_selectedCategoryIds.length > 1) {
                                      _selectedCategoryIds.remove(cat.id);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Quantidade e Estoque Mínimo
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Estoque Atual *' : 'Quantidade Inicial *',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(
                                    hintText: '0',
                                    suffixText: 'un',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Informe a quantidade';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Valor inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estoque Mínimo (Alerta)',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minQuantityController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(
                                    hintText: '10',
                                    suffixText: 'un',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Localização Física
                      Text(
                        'Localização Física (Opcional)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Gaveteiro A4, Prateleira 2, Rack SMD',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Observações
                      Text(
                        'Observações Técnicas (Opcional)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Lote recebido em 10/11, encapsulamento QFP-48',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Salvar Alterações' : 'Cadastrar Item',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
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
