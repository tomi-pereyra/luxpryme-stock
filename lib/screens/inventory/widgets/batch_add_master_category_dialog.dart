import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';

class BatchAddMasterCategoryDialog extends StatefulWidget {
  final String initialMasterCategoryId;
  final List<MasterCategoryModel> masterCategories;

  const BatchAddMasterCategoryDialog({
    super.key,
    required this.initialMasterCategoryId,
    required this.masterCategories,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialMasterCategoryId,
    required List<MasterCategoryModel> masterCategories,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchAddMasterCategoryDialog(
        initialMasterCategoryId: initialMasterCategoryId,
        masterCategories: masterCategories,
      ),
    );
  }

  @override
  State<BatchAddMasterCategoryDialog> createState() =>
      _BatchAddMasterCategoryDialogState();
}

class _BatchAddMasterCategoryDialogState
    extends State<BatchAddMasterCategoryDialog> {
  late String _selectedMasterCategoryId;
  final Set<String> _selectedProductIds = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final validCategories = widget.masterCategories
        .where((mc) => mc.id.toLowerCase() != 'todas')
        .toList();

    if (widget.initialMasterCategoryId.toLowerCase() != 'todas' &&
        validCategories.any((mc) => mc.id == widget.initialMasterCategoryId)) {
      _selectedMasterCategoryId = widget.initialMasterCategoryId;
    } else {
      _selectedMasterCategoryId =
          validCategories.isNotEmpty ? validCategories.first.id : 'eletronica';
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onToggleProduct(ProductModel product) {
    setState(() {
      if (_selectedProductIds.contains(product.id)) {
        _selectedProductIds.remove(product.id);
      } else {
        _selectedProductIds.add(product.id);
        // Regra solicitada: ao selecionar, limpa a busca e mantém o foco no campo
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (_selectedProductIds.isEmpty) return;

    final targetCategory = widget.masterCategories.firstWhere(
      (mc) => mc.id == _selectedMasterCategoryId,
      orElse: () => MasterCategoryModel(
        id: _selectedMasterCategoryId,
        name: _selectedMasterCategoryId,
      ),
    );

    final pinController = TextEditingController();
    String? pinError;

    final pinConfirmed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
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
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Autorização com PIN Mestre'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para adicionar ${_selectedProductIds.length} item(ns) à categoria mestre "${targetCategory.name}", digite o PIN de 4 dígitos:',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    obscureText: true,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: '••••',
                      counterText: '',
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        Navigator.of(ctx).pop(val);
                      }
                    },
                  ),
                  if (pinError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      pinError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final p = pinController.text.trim();
                    if (p.length == 4) {
                      Navigator.of(ctx).pop(p);
                    } else {
                      setDialogState(() => pinError = 'Digite exatamente 4 números.');
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pinConfirmed == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await InventoryService.instance.bulkAddProductsToMasterCategory(
        productIds: _selectedProductIds.toList(),
        targetMasterCategoryId: _selectedMasterCategoryId,
        pin: pinConfirmed,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Sucesso! ${_selectedProductIds.length} produtos adicionados à categoria "${targetCategory.name}".',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCategories = widget.masterCategories
        .where((mc) => mc.id.toLowerCase() != 'todas')
        .toList();

    final targetCategory = widget.masterCategories.firstWhere(
      (mc) => mc.id == _selectedMasterCategoryId,
      orElse: () => MasterCategoryModel(
        id: _selectedMasterCategoryId,
        name: _selectedMasterCategoryId,
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 750),
        child: Column(
          children: [
            // Header com Seleção da Categoria Destino
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_add, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+ Itens na Categoria',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            Text(
                              'Destino: ',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMasterCategoryId,
                                isDense: true,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                                items: validCategories.map((mc) {
                                  return DropdownMenuItem(
                                    value: mc.id,
                                    child: Text(mc.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMasterCategoryId = val);
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
            const Divider(height: 1, color: AppColors.border),

            // Barra de Busca no Canto Superior com Contador em Círculo Azul
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Pesquise para selecionar itens...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      if (_selectedProductIds.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          alignment: Alignment.center,
                          child: Text(
                            '${_selectedProductIds.length}',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                ),
              ),

            // Lista de Produtos
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: InventoryService.instance.streamProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allProducts = snapshot.data ?? [];
                  final filteredProducts = _searchQuery.isEmpty
                      ? allProducts
                      : allProducts
                          .where((p) => p.matchesSearch(_searchQuery))
                          .toList();

                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Nenhum item encontrado para "$_searchQuery".'
                              : 'Nenhum produto cadastrado.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final isSelected = _selectedProductIds.contains(product.id);
                      final alreadyInTarget = product.masterCategories.contains(_selectedMasterCategoryId);

                      return InkWell(
                        onTap: () => _onToggleProduct(product),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? AppColors.primary : AppColors.textMuted,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
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
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (product.internalCode != null &&
                                            product.internalCode!.isNotEmpty)
                                          Text(
                                            'Cód: ${product.internalCode}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11,
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
                                        Text(
                                          'Estoque: ${product.quantity} un',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (alreadyInTarget) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '✓ Já presente em ${targetCategory.name}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.stockNormal,
                                        ),
                                      ),
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
                },
              ),
            ),

            // Rodapé com Ações
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedProductIds.length} item(ns) selecionado(s)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedProductIds.isEmpty || _isSaving ? null : _handleConfirm,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Adicionar à ${targetCategory.name}'),
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
