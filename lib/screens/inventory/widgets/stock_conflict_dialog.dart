import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/stock_conflict_model.dart';
import '../../../data/services/inventory_service.dart';
import 'pin_confirmation_dialog.dart';

class StockConflictDialog extends StatefulWidget {
  final List<StockConflictModel> conflicts;

  const StockConflictDialog({
    super.key,
    required this.conflicts,
  });

  static Future<void> show(
    BuildContext context,
    List<StockConflictModel> conflicts,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StockConflictDialog(conflicts: conflicts),
    );
  }

  @override
  State<StockConflictDialog> createState() => _StockConflictDialogState();
}

class _StockConflictDialogState extends State<StockConflictDialog> {
  bool _isProcessing = false;

  Future<void> _handleZeroStock(StockConflictModel conflict) async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Zerar Saldo do Produto',
      subtitle:
          'Para redefinir o saldo de "${conflict.productName}" para 0 un, digite seu PIN Mestre:',
      itemName: conflict.productName,
      actionLabel: 'Confirmar Saldo 0 un',
      actionColor: AppColors.stockZero,
      actionIcon: Icons.exposure_zero,
    );

    if (pin == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await InventoryService.instance.resolveConflictSetStock(
        conflictId: conflict.id,
        productId: conflict.productId,
        newQuantity: 0,
        masterPin: pin,
        note: 'Resolução de Conflito: Saldo zerado manualmente (0 un).',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Saldo de "${conflict.productName}" corrigido para 0 un com sucesso.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSetActualStock(StockConflictModel conflict) async {
    final qtyController = TextEditingController();
    final pinController = TextEditingController();
    String? localError;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informar Saldo Real em Almoxarifado',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Item: ${conflict.productName}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo atual no sistema: ${conflict.currentQuantity} un',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade Física Contada (un)*',
                    hintText: 'Ex: 15',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'PIN Mestre de 4 dígitos*',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    localError!,
                    style: GoogleFonts.inter(color: AppColors.stockZero, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(qtyController.text.trim());
                  if (qty == null || qty < 0) {
                    setDialogState(() => localError = 'Informe uma quantidade válida (>= 0).');
                    return;
                  }
                  if (pinController.text.trim().length != 4) {
                    setDialogState(() => localError = 'Digite seu PIN de 4 dígitos.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirmar Correção'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || !mounted) return;

    final newQty = int.parse(qtyController.text.trim());
    final pin = pinController.text.trim();

    setState(() => _isProcessing = true);
    try {
      await InventoryService.instance.resolveConflictSetStock(
        conflictId: conflict.id,
        productId: conflict.productId,
        newQuantity: newQty,
        masterPin: pin,
        note: 'Resolução de Conflito: Contagem física confirmada em $newQty un.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Saldo de "${conflict.productName}" atualizado para $newQty un com sucesso.'),
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRevertDeficit(StockConflictModel conflict) async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Estornar Déficit Negativo',
      subtitle:
          'Deseja estornar as ${conflict.deficitAmount} un faltantes e restabelecer o saldo em 0 un? Digite seu PIN Mestre:',
      itemName: conflict.productName,
      actionLabel: 'Estornar (+${conflict.deficitAmount} un)',
      actionColor: AppColors.primary,
      actionIcon: Icons.restore,
    );

    if (pin == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await InventoryService.instance.resolveConflictRevertDeficit(
        conflictId: conflict.id,
        productId: conflict.productId,
        deficitAmount: conflict.deficitAmount,
        masterPin: pin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Déficit de ${conflict.deficitAmount} un estornado com sucesso.'),
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockConflictModel>>(
      stream: InventoryService.instance.streamStockConflicts(),
      initialData: widget.conflicts,
      builder: (context, snapshot) {
        final currentConflicts = snapshot.data ?? widget.conflicts;

        if (currentConflicts.isEmpty) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 52, color: AppColors.stockNormal),
                  const SizedBox(height: 12),
                  Text(
                    'Tudo Sincronizado!',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Todos os conflitos de estoque foram resolvidos com sucesso.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: AppColors.stockZero, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conflito de Sincronização de Estoque',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stockZero,
                              ),
                            ),
                            Text(
                              '${currentConflicts.length} item(ns) com saldo negativo detectados após saídas simultâneas.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
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
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Lista de Conflitos
                  Expanded(
                    child: ListView.separated(
                      itemCount: currentConflicts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = currentConflicts[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.productName,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Cód: ${c.productCode ?? c.internalCode ?? "N/A"}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFF87171)),
                                    ),
                                    child: Text(
                                      'Saldo: ${c.currentQuantity} un',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.stockZero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c.reason,
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.stockZero,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.exposure_zero, size: 16),
                                    label: Text('Zerar Saldo (0 un)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                    onPressed: _isProcessing ? null : () => _handleZeroStock(c),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: Text('Informar Saldo Real', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                    onPressed: _isProcessing ? null : () => _handleSetActualStock(c),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.restore, size: 16),
                                    label: Text('Estornar Déficit (+${c.deficitAmount} un)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                    onPressed: _isProcessing ? null : () => _handleRevertDeficit(c),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    onPressed: _isProcessing ? null : () => InventoryService.instance.dismissConflict(c.id),
                                    child: Text('Dispensar', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
