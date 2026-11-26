import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'pin_confirmation_dialog.dart';

class TrashBinDialog extends StatefulWidget {
  const TrashBinDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const TrashBinDialog(),
    );
  }

  @override
  State<TrashBinDialog> createState() => _TrashBinDialogState();
}

class _TrashBinDialogState extends State<TrashBinDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        setState(() => _searchQuery = '');
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchQuery != text) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRestoreProduct(ProductModel product) async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Restaurar Produto',
      subtitle: 'Digite seu PIN de 4 dígitos para autorizar o retorno do produto ao estoque ativo:',
      itemName: product.name,
      actionLabel: 'Restaurar',
      actionColor: AppColors.stockNormal,
      actionIcon: Icons.restore_from_trash,
    );

    if (pin == null) return;

    setState(() => _isProcessing = true);
    try {
      await InventoryService.instance.restoreProduct(product.id, pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'Sucesso! "${product.name}" foi restaurado ao estoque ativo.',
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

  Future<void> _handleEmptyTrash(int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: AppColors.stockZero, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Esvaziar Lixeira'),
          ],
        ),
        content: Text(
          'Deseja realmente esvaziar a lixeira e remover permanentemente $count item(ns)? Esta ação não poderá ser desfeita.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stockZero,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esvaziar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Autorização com PIN Mestre',
      subtitle: 'Digite seu PIN de 4 dígitos para autorizar a limpeza definitiva da lixeira:',
      actionLabel: 'Confirmar Exclusão',
      actionColor: AppColors.stockZero,
      actionIcon: Icons.delete_forever,
    );

    if (pin == null) return;

    setState(() => _isProcessing = true);
    try {
      await InventoryService.instance.emptyTrash(pin: pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Lixeira esvaziada com sucesso.',
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restore_from_trash,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lixeira de Produtos',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Visualize e restaure produtos excluídos de volta ao estoque',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<ProductModel>>(
                    stream: InventoryService.instance.streamTrashProducts(),
                    builder: (context, snapshot) {
                      final trashList = snapshot.data ?? [];
                      if (trashList.isEmpty) return const SizedBox.shrink();
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.stockZero,
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: Text(
                          'Esvaziar',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isProcessing ? null : () => _handleEmptyTrash(trashList.length),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Barra de Busca
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquise itens na lixeira por nome, código ou P/N...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFD97706), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
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
                    borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                  ),
                ),
              ),
            ),

            // Conteúdo / Lista de Produtos Excluídos
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: InventoryService.instance.streamTrashProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allTrash = snapshot.data ?? [];
                  final filteredTrash = _searchQuery.isEmpty
                      ? allTrash
                      : ProductModel.filterAndSortByRelevance(allTrash, _searchQuery);

                  if (filteredTrash.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 40,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Nenhum item excluído encontrado para "$_searchQuery".'
                                  : 'A lixeira está vazia.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tente pesquisar por outro termo.'
                                  : 'Produtos que forem excluídos ficarão armazenados aqui e poderão ser recuperados a qualquer momento.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredTrash.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = filteredTrash[index];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.stockZero,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
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
                                        'Estoque: ${product.quantity} ${product.unitSymbol}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (product.notes != null && product.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      product.notes!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDCFCE7),
                                foregroundColor: AppColors.stockNormal,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFF86EFAC)),
                                ),
                              ),
                              icon: const Icon(Icons.restore, size: 16),
                              label: Text(
                                'Restaurar',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: _isProcessing ? null : () => _handleRestoreProduct(product),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Rodapé
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  StreamBuilder<List<ProductModel>>(
                    stream: InventoryService.instance.streamTrashProducts(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Text(
                        '$count item(ns) na lixeira',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
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
