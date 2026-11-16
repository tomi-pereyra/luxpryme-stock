import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';
import 'pin_confirmation_dialog.dart';

class MasterCategoriesManageDialog extends StatefulWidget {
  const MasterCategoriesManageDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const MasterCategoriesManageDialog(),
    );
  }

  @override
  State<MasterCategoriesManageDialog> createState() =>
      _MasterCategoriesManageDialogState();
}

class _MasterCategoriesManageDialogState
    extends State<MasterCategoriesManageDialog> {
  final List<Color> _availableColors = const [
    Color(0xFF2563EB), // Azul
    Color(0xFF059669), // Verde
    Color(0xFFD97706), // Âmbar / Laranja
    Color(0xFF7C3AED), // Roxo
    Color(0xFFDC2626), // Vermelho
    Color(0xFF0284C7), // Azul Claro
    Color(0xFF0D9488), // Verde Água
    Color(0xFF64748B), // Cinza Slate
    Color(0xFF475569), // Chumbo
    Color(0xFFDB2777), // Rosa Escuro
  ];

  final List<Map<String, dynamic>> _availableIcons = const [
    {'name': 'memory', 'icon': Icons.memory, 'label': 'Eletrônica/Chip'},
    {'name': 'precision_manufacturing', 'icon': Icons.precision_manufacturing_outlined, 'label': 'Produção'},
    {'name': 'build', 'icon': Icons.build_outlined, 'label': 'Preparação'},
    {'name': 'all_inbox', 'icon': Icons.all_inbox_outlined, 'label': 'Embalamento'},
    {'name': 'handyman', 'icon': Icons.handyman_outlined, 'label': 'Oficina/Ferramentas'},
    {'name': 'electrical_services', 'icon': Icons.electrical_services_outlined, 'label': 'Elétrica/Cabos'},
    {'name': 'cable', 'icon': Icons.cable_outlined, 'label': 'Chicotes'},
    {'name': 'inventory_2', 'icon': Icons.inventory_2_outlined, 'label': 'Almoxarifado'},
    {'name': 'hardware', 'icon': Icons.hardware_outlined, 'label': 'Ferragens'},
    {'name': 'science', 'icon': Icons.science_outlined, 'label': 'Laboratório/Testes'},
  ];

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _openAddMasterCategoryDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final pinController = TextEditingController();
    Color selectedColor = _availableColors[2];
    String selectedIcon = 'build';
    String? errorText;

    await showDialog(
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
                  child: const Icon(Icons.add_box_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nova Categoria Mestre',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Text(
                        'Ex: Preparação, Embalamento, Cabos',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.stockZero.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.stockZero.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.stockZero, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: GoogleFonts.inter(color: AppColors.stockZero, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Nome da Categoria Mestre
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Categoria Mestre *',
                      hintText: 'Ex: Preparação, Embalamento, etc.',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (Opcional)',
                      hintText: 'Finalidade ou setor de atuação desta categoria',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seleção de Cor
                  Text(
                    'Cor de Identificação:',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected = selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Seleção de Ícone
                  Text(
                    'Ícone Representativo:',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableIcons.map((item) {
                      final isSelected = selectedIcon == item['name'];
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = item['name'] as String),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedColor.withValues(alpha: 0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? selectedColor : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item['icon'] as IconData,
                                  size: 16, color: isSelected ? selectedColor : AppColors.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? selectedColor : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // PIN Mestre
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
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Autorização por PIN Mestre (4 dígitos):',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Digite o PIN Mestre (ex: Supervisor)',
                            counterText: '',
                            prefixIcon: Icon(Icons.lock_outline),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Salvar Categoria Mestre'),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final pin = pinController.text.trim();

                  if (name.isEmpty) {
                    setDialogState(() => errorText = 'Informe o nome da categoria mestre.');
                    return;
                  }
                  if (pin.length != 4) {
                    setDialogState(() => errorText = 'O PIN deve conter exatamente 4 dígitos.');
                    return;
                  }

                  try {
                    await InventoryService.instance.createMasterCategory(
                      name: name,
                      description: descController.text.trim(),
                      colorHex: _colorToHex(selectedColor),
                      iconName: selectedIcon,
                      masterPin: pin,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.stockNormal,
                        content: Text('Categoria mestre "$name" criada com sucesso!'),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() {
                      errorText = e.toString().replaceAll('Exception: ', '');
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

  Future<void> _openEditMasterCategoryDialog(MasterCategoryModel category) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: category.name);
    final descController = TextEditingController(text: category.description ?? '');
    final pinController = TextEditingController();
    Color selectedColor = category.color;
    String selectedIcon = category.iconName ?? 'build';
    String? errorText;

    await showDialog(
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
                    color: selectedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, color: selectedColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modificar Categoria Mestre',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Text(
                        'Identificador: ${category.id}',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.stockZero.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.stockZero.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.stockZero, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: GoogleFonts.inter(color: AppColors.stockZero, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Nome da Categoria Mestre
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Categoria Mestre *',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seleção de Cor
                  Text(
                    'Cor de Identificação:',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected = selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Seleção de Ícone
                  Text(
                    'Ícone Representativo:',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableIcons.map((item) {
                      final isSelected = selectedIcon == item['name'];
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = item['name'] as String),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedColor.withValues(alpha: 0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? selectedColor : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item['icon'] as IconData,
                                  size: 16, color: isSelected ? selectedColor : AppColors.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                item['label'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? selectedColor : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // PIN Mestre
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
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Autorização por PIN Mestre (4 dígitos):',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Digite o PIN Mestre (ex: Supervisor)',
                            counterText: '',
                            prefixIcon: Icon(Icons.lock_outline),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Salvar Alterações'),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final pin = pinController.text.trim();

                  if (name.isEmpty) {
                    setDialogState(() => errorText = 'O nome não pode ser vazio.');
                    return;
                  }
                  if (pin.length != 4) {
                    setDialogState(() => errorText = 'O PIN deve conter exatamente 4 dígitos.');
                    return;
                  }

                  try {
                    await InventoryService.instance.updateMasterCategory(
                      id: category.id,
                      name: name,
                      description: descController.text.trim(),
                      colorHex: _colorToHex(selectedColor),
                      iconName: selectedIcon,
                      masterPin: pin,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.stockNormal,
                        content: Text('Categoria mestre "$name" atualizada com sucesso!'),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() {
                      errorText = e.toString().replaceAll('Exception: ', '');
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

  Future<void> _handleDeleteMasterCategory(
    MasterCategoryModel category,
    int productCount,
  ) async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Eliminar Categoria Mestre',
      subtitle: productCount > 0
          ? 'ATENÇÃO: Existem $productCount produto(s) nesta categoria mestre.\n'
              'Ao excluir, esses produtos serão mantidos e transferidos automaticamente para a categoria "Outros".\n'
              'Digite seu PIN Mestre para confirmar:'
          : 'Para eliminar a categoria mestre "${category.name}", digite seu PIN Mestre:',
      itemName: category.name,
      actionLabel: 'Excluir Categoria Mestre',
      actionColor: AppColors.stockZero,
      actionIcon: Icons.delete_forever,
    );

    if (pin == null) return;

    try {
      await InventoryService.instance.deleteMasterCategory(
        id: category.id,
        masterPin: pin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('Categoria mestre "${category.name}" eliminada com sucesso.'),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dashboard_customize_outlined,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categorias Mestres Industriais',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Setores estruturais de controle com autorização por PIN',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Aviso Informativo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Apenas operadores com PIN Mestre (ex: Supervisor Geral) possuem autorização para adicionar, modificar ou excluir categorias mestres.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de Categorias Mestres
              Expanded(
                child: StreamBuilder<List<MasterCategoryModel>>(
                  stream: InventoryService.instance.streamMasterCategories(),
                  builder: (context, snapshot) {
                    final masterCats = snapshot.data ?? InventoryService.instance.masterCategories;

                    return StreamBuilder<List<ProductModel>>(
                      stream: InventoryService.instance.streamProducts(),
                      builder: (context, prodSnapshot) {
                        final products = prodSnapshot.data ?? [];

                        return ListView.separated(
                          itemCount: masterCats.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final mc = masterCats[index];
                            final count = products
                                .where((p) => p.masterCategories.contains(mc.id))
                                .length;

                            final isOutros = mc.id == 'outros';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  // Badge Colorida com Ícone
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: mc.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(mc.icon, color: mc.color, size: 24),
                                  ),
                                  const SizedBox(width: 14),

                                  // Detalhes da Categoria Mestre
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              mc.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: mc.color.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                mc.id,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: mc.color,
                                                ),
                                              ),
                                            ),
                                            if (mc.isSystemDefault) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.background,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: Text(
                                                  'Padrão',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (mc.description != null &&
                                            mc.description!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            mc.description!,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.inventory_2_outlined,
                                                size: 13, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$count produto(s) vinculados',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Ações: Editar e Excluir
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        tooltip: 'Modificar Categoria Mestre (Requer PIN Mestre)',
                                        onPressed: () => _openEditMasterCategoryDialog(mc),
                                      ),
                                      if (!isOutros) ...[
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 20, color: AppColors.stockZero),
                                          tooltip: 'Eliminar Categoria Mestre (Requer PIN Mestre)',
                                          onPressed: () =>
                                              _handleDeleteMasterCategory(mc, count),
                                        ),
                                      ],
                                    ],
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

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Botões Inferiores
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      'Nova Categoria Mestre',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _openAddMasterCategoryDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
