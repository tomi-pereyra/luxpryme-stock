import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/master_category_model.dart';
import '../../data/models/operator_pin_model.dart';
import '../../data/services/inventory_service.dart';
import '../inventory/widgets/master_categories_manage_dialog.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedMasterCategory = 'eletronica';

  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleCreatePin() async {
    if (!InventoryService.instance.isAdminUser) {
      setState(() => _errorMessage = 'Acesso negado: Apenas tomibr20@gmail.com pode criar PINs.');
      return;
    }

    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe o nome do operador ou setor.');
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorMessage = 'O PIN deve conter exatamente 4 dígitos numéricos.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      await InventoryService.instance.createOperatorPin(
        name: name,
        pin: pin,
        masterCategory: _selectedMasterCategory,
      );
      _nameController.clear();
      _pinController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text(
              'PIN para "$name" cadastrado com sucesso!',
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
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _handleDeletePin(OperatorPinModel pinModel) async {
    if (!InventoryService.instance.isAdminUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.stockZero,
          content: Text('Acesso negado: Apenas tomibr20@gmail.com pode revogar PINs.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Autorização?'),
        content: Text(
          'Deseja realmente revogar e excluir o PIN do operador "${pinModel.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stockZero),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revogar PIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await InventoryService.instance.deleteOperatorPin(pinModel.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('PIN de "${pinModel.name}" excluído.'),
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
    final isAdmin = InventoryService.instance.isAdminUser;
    final currentEmail = InventoryService.instance.currentUserEmail;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Acesso Restrito'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_outlined,
                      size: 58,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acesso Exclusivo ao Administrador',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'O Painel do Administrador e gerenciamento de PINs é restrito exclusivamente ao usuário tomibr20@gmail.com.\n\nSua sessão atual: ${currentEmail ?? "Não autenticado"}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Voltar ao Estoque'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Painel do Administrador (Windows Desktop)',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Badge de Usuário Administrador Autenticado
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sessão autorizada como Administrador: tomibr20@gmail.com',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Card de Introdução
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 36, color: AppColors.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestão de PINs de Segurança para Retirada de Estoque',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cadastre os PINs de 4 dígitos que os operadores, técnicos e monitores de linha usarão para autorizar a baixa de componentes e placas no carrinho de separação.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card de Gestão de Categorias Mestres Industriais
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dashboard_customize_outlined,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Setores da Fábrica',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Adicione, edite ou remova setores da fábrica (ex: Preparação, Embalamento) com validação de PIN Mestre.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(
                          'Gerenciar Setores',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => MasterCategoriesManageDialog.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Formulário de Cadastro de Novo PIN
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cadastrar Novo Operador / PIN Autorizado',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome do Operador ou Setor',
                                hintText: 'Ex: Tomas (Supervisor), Roberto (Monitor), Linha SMD',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'PIN (4 dígitos)',
                                hintText: 'Ex: 4 dígitos',
                                counterText: '',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Autorização por Setor:',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StreamBuilder<List<MasterCategoryModel>>(
                              stream: InventoryService.instance.streamMasterCategories(),
                              builder: (context, snapshot) {
                                final masterCats = snapshot.data ?? InventoryService.instance.masterCategories;

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      avatar: const Icon(Icons.stars, size: 16, color: Color(0xFF7C3AED)),
                                      label: const Text('Mestre (Acesso a Todos os Setores)'),
                                      selected: _selectedMasterCategory == 'todas',
                                      selectedColor: const Color(0xFFEDE9FE),
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedMasterCategory = 'todas');
                                      },
                                    ),
                                    ...masterCats.map((mc) {
                                      final isSelected = _selectedMasterCategory == mc.id;
                                      return ChoiceChip(
                                        avatar: Icon(mc.icon, size: 16, color: isSelected ? mc.color : AppColors.textSecondary),
                                        label: Text(mc.name),
                                        selected: isSelected,
                                        selectedColor: mc.color.withValues(alpha: 0.15),
                                        onSelected: (val) {
                                          if (val) setState(() => _selectedMasterCategory = mc.id);
                                        },
                                      );
                                    }),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            ),
                            icon: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add_moderator),
                            label: Text(
                              _isCreating ? 'Salvando...' : 'Cadastrar PIN',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            onPressed: _isCreating ? null : _handleCreatePin,
                          ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.stockZero),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de PINs Cadastrados
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'PINs Autorizados Atualmente:',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<OperatorPinModel>>(
                        stream: InventoryService.instance.streamOperatorPins(),
                        builder: (context, snapshot) {
                          final pins = snapshot.data ?? [];
                          if (pins.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('Nenhum PIN cadastrado.'),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pins.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final p = pins[index];
                              Color badgeColor;
                              Color badgeBg;
                              if (p.isMasterPin) {
                                badgeColor = const Color(0xFF7C3AED);
                                badgeBg = const Color(0xFFEDE9FE);
                              } else {
                                final mc = InventoryService.instance.masterCategories.firstWhere(
                                  (m) => m.id.toLowerCase() == p.masterCategory.toLowerCase(),
                                  orElse: () => MasterCategoryModel(
                                    id: p.masterCategory,
                                    name: p.masterCategoryLabel,
                                  ),
                                );
                                badgeColor = mc.color;
                                badgeBg = mc.color.withValues(alpha: 0.12);
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: badgeBg,
                                  child: Icon(Icons.vpn_key, size: 18, color: badgeColor),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      p.name,
                                      style: GoogleFonts.inter(
                                          fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        p.masterCategoryLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'PIN: ${p.pin} • Autorizado para modificações em: ${p.masterCategoryLabel}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.stockZero),
                                  tooltip: 'Revogar este PIN',
                                  onPressed: () => _handleDeletePin(p),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
