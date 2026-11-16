import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'add_to_cart_dialog.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenCart,
  });

  Color _getStatusColor() {
    if (product.isOutOfStock) return AppColors.stockZero;
    if (product.isLowStock) return AppColors.stockLow;
    return AppColors.stockNormal;
  }

  String _getStatusText() {
    if (product.isOutOfStock) return 'ESGOTADO';
    if (product.isLowStock) return 'ESTOQUE BAIXO';
    return 'NORMAL';
  }

  /// Ajuste rápido 1 por 1 instantâneo e sem senha
  Future<void> _quickChangeStock(BuildContext context, int delta) async {
    if (delta < 0 && product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.stockZero,
          content: Text('O produto já está com 0 unidades.'),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    try {
      await InventoryService.instance.quickAdjustUnit(
        product: product,
        delta: delta,
      );
    } catch (e) {
      if (context.mounted) {
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
    final statusColor = _getStatusColor();
    final statusText = _getStatusText();
    final categoryNames = product.categoryNames ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Tags de Categorias Múltiplas e Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categorias múltiplas em Wrap
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: categoryNames.isEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sem Categoria',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          ]
                        : categoryNames.map((cName) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cName,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                ),
                const SizedBox(width: 8),

                // Alerta de Estoque
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Menu de Ações
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Editar item'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.stockZero),
                          SizedBox(width: 8),
                          Text('Excluir item', style: TextStyle(color: AppColors.stockZero)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Nome do Produto
            Text(
              product.name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Códigos: Interno e Fabricante / P/N
            Wrap(
              spacing: 12,
              children: [
                if (product.internalCode != null && product.internalCode!.isNotEmpty)
                  Text(
                    'Cód. Int: ${product.internalCode}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  )
                else if (product.code != null && product.code!.isNotEmpty)
                  Text(
                    'Cód: ${product.code}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (product.manufacturerCode != null && product.manufacturerCode!.isNotEmpty)
                  Text(
                    'P/N: ${product.manufacturerCode}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),

            // Localização
            if (product.location != null && product.location!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      product.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20, color: AppColors.border),

            // Controles de Estoque
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Saldo em Estoque
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTOQUE DISPONÍVEL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          NumberFormat('#,###', 'pt_BR').format(product.quantity),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'un',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (product.minQuantity > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(Mín: ${product.minQuantity})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Controles Rápidos: [-1 Instantâneo] | [Pegar no Carrinho] | [+1 Instantâneo]
                Row(
                  children: [
                    // Botão Instantâneo -1 (Sem popup nem senha)
                    InkWell(
                      onTap: product.quantity > 0
                          ? () => _quickChangeStock(context, -1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: product.quantity > 0
                              ? Colors.grey.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 20,
                          color: product.quantity > 0
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botão "Pegar / Movimentar" -> Abre diálogo para colocar no Carrinho
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.primaryLight),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AddToCartDialog(
                            product: product,
                            onOpenCart: onOpenCart,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: Text(
                        'Pegar...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botão Instantâneo +1 (Sem popup nem senha)
                    InkWell(
                      onTap: () => _quickChangeStock(context, 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryLight),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
