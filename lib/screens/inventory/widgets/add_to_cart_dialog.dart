import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/cart_service.dart';

class AddToCartDialog extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onOpenCart;

  const AddToCartDialog({
    super.key,
    required this.product,
    this.onOpenCart,
  });

  @override
  State<AddToCartDialog> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends State<AddToCartDialog> {
  final _qtyController = TextEditingController(text: '10');
  bool _isWithdrawal = true; // Padrão: Retirar do estoque
  String? _errorMessage;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _confirmAddToCart() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _errorMessage = 'Informe uma quantidade maior que zero.');
      return;
    }

    if (_isWithdrawal && qty > widget.product.quantity) {
      setState(() {
        _errorMessage =
            'Atenção: O estoque atual é de ${widget.product.quantity} un. Você não pode retirar $qty un.';
      });
      return;
    }

    CartService.instance.addItem(
      product: widget.product,
      quantity: qty,
      isWithdrawal: _isWithdrawal,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$qty un de "${widget.product.name}" adicionado ao carrinho.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: widget.onOpenCart != null
            ? SnackBarAction(
                label: 'VER CARRINHO',
                textColor: Colors.amberAccent,
                onPressed: widget.onOpenCart!,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar ao Carrinho',
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
            // Saldo atual
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estoque Disponível:',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${widget.product.quantity} unidades',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.product.quantity <= 0
                          ? AppColors.stockZero
                          : AppColors.stockNormal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tipo: Retirar vs Devolver
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isWithdrawal = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isWithdrawal ? const Color(0xFFFEE2E2) : Colors.grey.shade100,
                        border: Border.all(
                          color: _isWithdrawal ? AppColors.stockZero : AppColors.border,
                          width: _isWithdrawal ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.outbox_outlined,
                            size: 16,
                            color: _isWithdrawal ? AppColors.stockZero : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Retirar (Pegar)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isWithdrawal ? AppColors.stockZero : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isWithdrawal = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isWithdrawal ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
                        border: Border.all(
                          color: !_isWithdrawal ? AppColors.stockNormal : AppColors.border,
                          width: !_isWithdrawal ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.move_to_inbox_outlined,
                            size: 16,
                            color: !_isWithdrawal ? AppColors.stockNormal : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Repor (Entrada)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !_isWithdrawal ? AppColors.stockNormal : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quantidade
            Text(
              'Quantidade a ${_isWithdrawal ? "retirar" : "adicionar"}:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  _isWithdrawal ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  color: _isWithdrawal ? AppColors.stockZero : AppColors.stockNormal,
                ),
                suffixText: 'un',
              ),
            ),

            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [5, 10, 20, 50, 100].map((numVal) {
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () => _qtyController.text = numVal.toString(),
                  child: Text('$numVal un', style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _confirmAddToCart,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isWithdrawal ? AppColors.primary : AppColors.stockNormal,
          ),
          child: Text(
            'Colocar no Carrinho',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
