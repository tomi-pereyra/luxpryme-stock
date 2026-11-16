import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';

class StockAdjustDialog extends StatefulWidget {
  final ProductModel product;

  const StockAdjustDialog({
    super.key,
    required this.product,
  });

  @override
  State<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<StockAdjustDialog> {
  final _amountController = TextEditingController(text: '1');
  bool _isAddition = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitAdjustment() async {
    final int? amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Informe um valor numérico maior que 0.';
      });
      return;
    }

    final int delta = _isAddition ? amount : -amount;
    final int simulatedNewStock = widget.product.quantity + delta;

    if (simulatedNewStock < 0) {
      setState(() {
        _errorMessage =
            'Atenção: O estoque atual é de ${widget.product.quantity} un. Não é possível retirar $amount un.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await InventoryService.instance.adjustStock(
        productId: widget.product.id,
        currentQuantity: widget.product.quantity,
        delta: delta,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _isAddition ? AppColors.stockNormal : AppColors.primary,
            content: Text(
              _isAddition
                  ? 'Entrada registrada com sucesso! (+ $amount un)'
                  : 'Saída registrada com sucesso! (- $amount un)',
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
    final int currentStock = widget.product.quantity;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sync_alt, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movimentar Estoque',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status do Estoque Atual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estoque Atual:',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '$currentStock unidades',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: currentStock <= 0
                          ? AppColors.stockZero
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seleção de Tipo: Entrada (+) ou Saída (-)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isAddition = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isAddition
                            ? const Color(0xFFDCFCE7)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: _isAddition ? AppColors.stockNormal : AppColors.border,
                          width: _isAddition ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: _isAddition ? AppColors.stockNormal : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Entrada (+)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _isAddition ? AppColors.stockNormal : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isAddition = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isAddition
                            ? const Color(0xFFFEE2E2)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: !_isAddition ? AppColors.stockZero : AppColors.border,
                          width: !_isAddition ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                            color: !_isAddition ? AppColors.stockZero : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Saída (-)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !_isAddition ? AppColors.stockZero : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo Quantidade
            Text(
              'Quantidade a ${_isAddition ? "adicionar" : "subtrair"}:',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  _isAddition ? Icons.add : Icons.remove,
                  color: _isAddition ? AppColors.stockNormal : AppColors.stockZero,
                ),
                hintText: '1',
              ),
            ),

            // Botões de Atalho Rápido (+10, +50, +100)
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [1, 5, 10, 50, 100].map((numVal) {
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () {
                    _amountController.text = numVal.toString();
                  },
                  child: Text('$numVal un', style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
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
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAdjustment,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isAddition ? AppColors.stockNormal : AppColors.primary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _isAddition ? 'Confirmar Entrada' : 'Confirmar Saída',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
