import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/inventory_service.dart';

class CartModal extends StatefulWidget {
  const CartModal({super.key});

  @override
  State<CartModal> createState() => _CartModalState();
}

class _CartModalState extends State<CartModal> {
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _requestPinAndCheckout() async {
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
                    child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Autorização por PIN'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para concluir a retirada/movimentação dos itens, digite seu PIN de 4 dígitos:',
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
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final noteText = _notesController.text.trim();
      await InventoryService.instance.checkoutCart(
        cartItems: CartService.instance.items,
        pin: pinConfirmed,
        notes: noteText.isNotEmpty ? noteText : null,
      );

      final totalItems = CartService.instance.itemCount;
      final totalPieces = CartService.instance.totalPieces;
      CartService.instance.clear();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Sucesso! Movimentação de $totalPieces peças ($totalItems itens) concluída e registrada.',
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
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final items = CartService.instance.items;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carrinho de Separação',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${items.length} itens • ${CartService.instance.totalPieces} peças no total',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () => CartService.instance.clear(),
                          child: const Text('Limpar', style: TextStyle(color: AppColors.stockZero)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Lista de Itens do Carrinho
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.remove_shopping_cart_outlined,
                                    size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhum item adicionado ao carrinho',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Clique em "Pegar / Movimentar" em qualquer componente da lista.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isWithdraw = item.isWithdrawal;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  // Badge Retirada ou Reposição
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isWithdraw
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isWithdraw ? 'RETIRAR' : 'REPOR',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isWithdraw
                                            ? AppColors.stockZero
                                            : AppColors.stockNormal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Detalhes do Produto
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Estoque atual: ${item.product.quantity} ${item.product.unitSymbol}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Controles de Quantidade
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        onPressed: () {
                                          CartService.instance
                                              .updateQuantity(index, item.quantity - 1);
                                        },
                                      ),
                                      Text(
                                        '${item.quantity} ${item.product.unitSymbol}',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        onPressed: () {
                                          if (isWithdraw &&
                                              item.quantity + 1 > item.product.quantity) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Quantidade solicitada excede o estoque disponível.'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                            return;
                                          }
                                          CartService.instance
                                              .updateQuantity(index, item.quantity + 1);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: AppColors.stockZero),
                                        onPressed: () => CartService.instance.removeItem(index),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  const SizedBox(height: 8),
                ],

                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: TextField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primary, size: 20),
                        labelText: 'Observação / Motivo (Opcional)',
                        hintText: 'Ex: Lote 42, Produção Placa X, Manutenção, OS 108...',
                        labelStyle: GoogleFonts.inter(fontSize: 12),
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
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
                ],

                // Footer
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Total a movimentar: ${CartService.instance.totalPieces} un',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.lock_open, size: 18),
                                label: Text(
                                  _isProcessing ? 'Processando...' : 'Finalizar com PIN',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                onPressed: (items.isEmpty || _isProcessing) ? null : _requestPinAndCheckout,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total a movimentar: ${CartService.instance.totalPieces} un',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.lock_open, size: 18),
                            label: Text(
                              _isProcessing ? 'Processando...' : 'Finalizar com PIN',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            onPressed: (items.isEmpty || _isProcessing) ? null : _requestPinAndCheckout,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
