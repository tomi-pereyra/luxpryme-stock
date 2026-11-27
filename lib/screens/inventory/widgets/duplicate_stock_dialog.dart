import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'pin_confirmation_dialog.dart';

class DuplicateStockDialog extends StatefulWidget {
  final ProductModel product;

  const DuplicateStockDialog({
    super.key,
    required this.product,
  });

  static Future<bool?> show(BuildContext context, ProductModel product) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DuplicateStockDialog(product: product),
    );
  }

  /// Quando um card consolidado na aba "Todas" possui múltiplos estoques separados por setor,
  /// exibe um seletor rápido para o usuário escolher qual estoque setorial deseja movimentar ou editar.
  static Future<ProductModel?> pickSectorStock(
    BuildContext context, {
    required ProductModel consolidatedProduct,
    required String actionTitle,
  }) async {
    if (!consolidatedProduct.hasSeparateSectorStocks) {
      return consolidatedProduct;
    }

    final masterCats = InventoryService.instance.masterCategories;

    return showDialog<ProductModel>(
      context: context,
      builder: (ctx) {
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
                child: const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionTitle,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      consolidatedProduct.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Este produto possui estoques separados em mais de um setor. Escolha qual estoque deseja utilizar:',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...consolidatedProduct.splitStocks.map((stock) {
                  final sectorNames = stock.masterCategories.map((mcId) {
                    final found = masterCats.where((m) => m.id.toLowerCase() == mcId.toLowerCase());
                    return found.isNotEmpty ? found.first.name : mcId;
                  }).join(' / ');

                  final firstSectorId = stock.masterCategories.isNotEmpty ? stock.masterCategories.first : 'eletronica';
                  final sectorModel = masterCats.firstWhere(
                    (m) => m.id.toLowerCase() == firstSectorId.toLowerCase(),
                    orElse: () => MasterCategoryModel(id: firstSectorId, name: sectorNames),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(stock),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sectorModel.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sectorModel.color.withValues(alpha: 0.35), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Icon(sectorModel.icon, color: sectorModel.color, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Setor: $sectorNames',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (stock.location != null && stock.location!.trim().isNotEmpty)
                                    Text(
                                      'Local: ${stock.location}',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: sectorModel.color.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${stock.quantity} ${stock.unitSymbol}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: sectorModel.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  State<DuplicateStockDialog> createState() => _DuplicateStockDialogState();
}

class _DuplicateStockDialogState extends State<DuplicateStockDialog> {
  final TextEditingController _qtyController = TextEditingController(text: '0');
  late TextEditingController _locationController;
  String? _selectedTargetSectorId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.product.location ?? '');
    final available = _getAvailableTargetSectors();
    if (available.isNotEmpty) {
      _selectedTargetSectorId = available.first.id;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Set<String> _getOccupiedSectors() {
    final allProducts = InventoryService.instance.currentProducts;
    final groupKey = widget.product.productGroupKey;
    final occupied = <String>{};
    for (final p in allProducts) {
      if (p.isArchived == widget.product.isArchived && p.productGroupKey == groupKey) {
        for (final mc in p.masterCategories) {
          occupied.add(mc.toLowerCase());
        }
      }
    }
    for (final mc in widget.product.masterCategories) {
      occupied.add(mc.toLowerCase());
    }
    return occupied;
  }

  List<MasterCategoryModel> _getAvailableTargetSectors() {
    final allSectors = InventoryService.instance.masterCategories;
    final occupied = _getOccupiedSectors();
    return allSectors
        .where((mc) => !occupied.contains(mc.id.toLowerCase()))
        .toList();
  }

  Future<void> _handleConfirm() async {
    if (_selectedTargetSectorId == null) {
      setState(() => _errorMessage = 'Selecione o setor de destino.');
      return;
    }

    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty < 0) {
      setState(() => _errorMessage = 'Informe uma quantidade inicial válida (0 ou mais).');
      return;
    }

    final sectorName = InventoryService.instance.getMasterCategoryName(_selectedTargetSectorId!);

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirmar Duplicação de Estoque',
      subtitle:
          'Digite seu PIN de 4 dígitos para criar um estoque separado de "${widget.product.name}" no setor "$sectorName":',
      itemName: '${widget.product.name} ($qty ${widget.product.unitSymbol} em $sectorName)',
      actionLabel: 'Duplicar Estoque',
      actionColor: AppColors.primary,
      actionIcon: Icons.copy_all_outlined,
    );

    if (pin == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await InventoryService.instance.duplicateProductStockToSector(
        sourceProduct: widget.product,
        targetSectorId: _selectedTargetSectorId!,
        initialQuantity: qty,
        location: _locationController.text.trim(),
        pin: pin,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Estoque separado criado no setor "$sectorName" ($qty ${widget.product.unitSymbol})! Na aba "Todas" você verá a soma dos estoques.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSectors = InventoryService.instance.masterCategories;
    final occupiedSectors = _getOccupiedSectors();
    final availableSectors = _getAvailableTargetSectors();
    final unit = widget.product.unitSymbol;

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
            child: const Icon(Icons.copy_all_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicar Estoque em Outro Setor',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Cria um segundo estoque independente do mesmo produto',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumo do Produto
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (widget.product.internalCode != null &&
                            widget.product.internalCode!.isNotEmpty)
                          Text(
                            'Cód. Int: ${widget.product.internalCode}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        Text(
                          'Setor(es) com estoque atual: ${occupiedSectors.map(InventoryService.instance.getMasterCategoryName).join(", ")}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (availableSectors.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text(
                    'Este produto já possui estoque cadastrado em todos os setores disponíveis (${allSectors.map((s) => s.name).join(", ")}).',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFB45309)),
                  ),
                ),
              ] else ...[
                Text(
                  '1. Selecione o Setor para o Novo Estoque:',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSectors.map((mc) {
                    final isSelected = _selectedTargetSectorId == mc.id;
                    return ChoiceChip(
                      avatar: Icon(
                        mc.icon,
                        size: 16,
                        color: isSelected ? mc.color : AppColors.textSecondary,
                      ),
                      label: Text(mc.name),
                      selected: isSelected,
                      selectedColor: mc.color.withValues(alpha: 0.16),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? mc.color : AppColors.textPrimary,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedTargetSectorId = mc.id);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text(
                  '2. Quantidade Inicial neste Setor ($unit):',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: unit,
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  '3. Localização Física neste Setor (Opcional):',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Prateleira Produção B2, Gaveta 4...',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (availableSectors.isNotEmpty)
          ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.copy_all_outlined, size: 18),
            label: Text(
              _isSaving ? 'Criando...' : 'Duplicar Estoque',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            onPressed: _isSaving ? null : _handleConfirm,
          ),
      ],
    );
  }
}
