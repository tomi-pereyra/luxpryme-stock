import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/master_category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/inventory_service.dart';

enum SectorReportSortOrder {
  byInternalCode('Por Código Interno'),
  byName('Alfabético por Nome (A - Z)');

  final String label;
  const SectorReportSortOrder(this.label);
}

class SectorReportDialog extends StatefulWidget {
  final String initialSectorId;
  final bool isArchived;

  const SectorReportDialog({
    super.key,
    this.initialSectorId = 'todas',
    this.isArchived = false,
  });

  static Future<void> show(
    BuildContext context, {
    String initialSectorId = 'todas',
    bool isArchived = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SectorReportDialog(
        initialSectorId: initialSectorId,
        isArchived: isArchived,
      ),
    );
  }

  /// Utilitário compartilhado para salvar/exportar um arquivo PDF no Windows ou Android
  static Future<String?> saveOrSharePdfFile({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    if (!kIsWeb && Platform.isWindows) {
      String defaultDirPath;
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null && await downloadsDir.exists()) {
          defaultDirPath = downloadsDir.path;
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          defaultDirPath = docsDir.path;
        }
      } catch (_) {
        final docsDir = await getApplicationDocumentsDirectory();
        defaultDirPath = docsDir.path;
      }

      String? targetPath;
      try {
        final safeFileName = fileName.replaceAll("'", '');
        final safeDir = defaultDirPath.replaceAll("'", "''");
        final psScript = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.SaveFileDialog
\$dlg.Title = 'Exportar Relatorio como PDF'
\$dlg.Filter = 'Arquivo PDF (*.pdf)|*.pdf'
\$dlg.DefaultExt = 'pdf'
\$dlg.AddExtension = \$true
\$dlg.FileName = '$safeFileName'
\$dlg.InitialDirectory = '$safeDir'
\$owner = New-Object System.Windows.Forms.Form -Property @{TopMost = \$true; ShowInTaskbar = \$false}
\$res = \$dlg.ShowDialog(\$owner)
\$owner.Dispose()
if (\$res -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$dlg.FileName
} else {
  Write-Output '__CANCELLED__'
}
''';
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-Sta', '-Command', psScript],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        final output = result.stdout.toString().trim();
        if (output == '__CANCELLED__') {
          return null; // Cancelado pelo usuário na janela Salvar Como
        }
        if (result.exitCode == 0 && output.isNotEmpty) {
          targetPath = output.split(RegExp(r'[\r\n]+')).last.trim();
        }
      } catch (_) {
        // Fallback automático para a pasta Downloads/Documentos
      }

      targetPath ??= '$defaultDirPath${Platform.pathSeparator}$fileName';
      if (!targetPath.toLowerCase().endsWith('.pdf')) {
        targetPath = '$targetPath.pdf';
      }

      final file = File(targetPath);
      await file.writeAsBytes(pdfBytes, flush: true);

      // Abre o arquivo PDF recém-exportado no visualizador padrão do Windows
      try {
        await Process.run('cmd', ['/c', 'start', '', targetPath]);
      } catch (_) {}

      return targetPath;
    }

    // Android / Mobile: salva cópia local e abre o menu nativo de salvar/compartilhar arquivo PDF
    String? savedPath;
    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final file = File('${docs.path}/$fileName');
        await file.writeAsBytes(pdfBytes, flush: true);
        savedPath = file.path;
      } catch (_) {}
    }

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
    return savedPath ?? fileName;
  }

  /// Gera a lista de produtos filtrada por setor e status de arquivamento e ordenada conforme escolhido
  static List<ProductModel> buildSortedReportProducts({
    required List<ProductModel> sourceProducts,
    required String sectorId,
    required bool isArchived,
    required SectorReportSortOrder sortOrder,
  }) {
    final cleanSector = sectorId.trim().toLowerCase();
    var filtered = sourceProducts.where((p) {
      if (p.isArchived != isArchived) return false;
      if (cleanSector.isNotEmpty && cleanSector != 'todas') {
        return p.masterCategories.any((m) => m.toLowerCase() == cleanSector);
      }
      return true;
    }).toList();

    if (cleanSector.isEmpty || cleanSector == 'todas') {
      filtered = ProductModel.consolidateForAllSectorsView(filtered);
    }

    switch (sortOrder) {
      case SectorReportSortOrder.byInternalCode:
        filtered.sort(ProductModel.compareByInternalCode);
        break;
      case SectorReportSortOrder.byName:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  State<SectorReportDialog> createState() => _SectorReportDialogState();
}

class _SectorReportDialogState extends State<SectorReportDialog> {
  late String _selectedSectorId;
  SectorReportSortOrder _sortOrder = SectorReportSortOrder.byName;
  bool _isExporting = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    final masterCats = InventoryService.instance.masterCategories;
    if (widget.initialSectorId != 'todas' && widget.initialSectorId.trim().isNotEmpty) {
      _selectedSectorId = widget.initialSectorId;
    } else if (masterCats.isNotEmpty) {
      _selectedSectorId = masterCats.first.id;
    } else {
      _selectedSectorId = 'todas';
    }
  }

  String _getSectorDisplayName(List<MasterCategoryModel> masterCats) {
    if (_selectedSectorId == 'todas') return 'Todos os Setores';
    final match = masterCats.where((m) => m.id.toLowerCase() == _selectedSectorId.toLowerCase());
    return match.isNotEmpty ? match.first.name : _selectedSectorId;
  }

  String _sanitizePdfText(String input) {
    return input
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('•', '-')
        .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), '');
  }

  Future<({Uint8List bytes, String fileName})> _buildPdfDocument(
    List<ProductModel> reportItems,
    String sectorName,
  ) async {
    final doc = pw.Document();
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalUnits = reportItems.fold<int>(0, (acc, p) => acc + p.quantity);
    final reportTitle = widget.isArchived
        ? 'Relatório de Produtos Arquivados - Setor: $sectorName'
        : 'Relatório de Estoque do Setor: $sectorName';

    final headers = ['Código Interno', 'Nome do Produto', 'Qtd. Estoque'];
    final rows = reportItems.map((p) {
      final code = (p.internalCode ?? p.code ?? '').trim();
      return [
        _sanitizePdfText(code.isEmpty ? '-' : code),
        _sanitizePdfText(p.name),
        '${p.quantity} ${p.unitSymbol}',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _sanitizePdfText('${AppConstants.appName} v${AppConstants.appVersion}'),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'Gerado em: $nowStr',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _sanitizePdfText(reportTitle),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _sanitizePdfText(
                'Ordenação: ${_sortOrder.label}  |  Itens: ${reportItems.length}  |  Soma em estoque: $totalUnits un',
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: headers.map(_sanitizePdfText).toList(),
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(90),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FixedColumnWidth(75),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    final slug = InventoryService.instance.generateMasterCategorySlug(sectorName);
    final prefix = widget.isArchived ? 'relatorio_arquivados' : 'relatorio_setor';
    final fileName = '${prefix}_${slug}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final bytes = await doc.save();
    return (bytes: bytes, fileName: fileName);
  }

  Future<void> _exportPdfFile(List<ProductModel> reportItems, String sectorName) async {
    setState(() => _isExporting = true);
    try {
      final pdfData = await _buildPdfDocument(reportItems, sectorName);
      final savedPath = await SectorReportDialog.saveOrSharePdfFile(
        pdfBytes: pdfData.bytes,
        fileName: pdfData.fileName,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockNormal,
            content: Text('PDF exportado com sucesso em: $savedPath'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockZero,
            content: Text('Erro ao exportar PDF: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _printPdf(List<ProductModel> reportItems, String sectorName) async {
    setState(() => _isPrinting = true);
    try {
      final pdfData = await _buildPdfDocument(reportItems, sectorName);
      await Printing.layoutPdf(
        name: pdfData.fileName,
        onLayout: (format) async => pdfData.bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.stockZero,
            content: Text('Erro ao imprimir PDF: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _exportCsv(List<ProductModel> reportItems, String sectorName) async {
    final buffer = StringBuffer('\uFEFF'); // BOM UTF-8 para compatibilidade direta com Excel
    buffer.writeln('Codigo_Interno;Nome;Quantidade_Estoque');

    for (final p in reportItems) {
      final code = (p.internalCode ?? p.code ?? '').trim().replaceAll(';', ',');
      final cleanName = p.name.replaceAll(';', ',');
      buffer.writeln('${code.isEmpty ? "-" : code};$cleanName;${p.quantity} ${p.unitSymbol}');
    }

    final csvContent = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csvContent));

    String? savedPath;
    if (!kIsWeb) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final slug = InventoryService.instance.generateMasterCategorySlug(sectorName);
        final prefix = widget.isArchived ? 'relatorio_arquivados' : 'relatorio_setor';
        final fileName = '${prefix}_${slug}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
        final file = File('${docs.path}/$fileName');
        await file.writeAsString(csvContent);
        savedPath = file.path;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.stockNormal,
          content: Text(
            savedPath != null
                ? 'CSV copiado e salvo em: $savedPath'
                : 'Relatório CSV copiado para a área de transferência!',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MasterCategoryModel>>(
      stream: InventoryService.instance.streamMasterCategories(),
      builder: (context, masterSnap) {
        final masterCats = masterSnap.data ?? InventoryService.instance.masterCategories;
        final sectorName = _getSectorDisplayName(masterCats);

        return StreamBuilder<List<ProductModel>>(
          stream: InventoryService.instance.streamProducts(),
          builder: (context, prodSnap) {
            final allProducts = prodSnap.data ?? InventoryService.instance.currentProducts;
            final reportItems = SectorReportDialog.buildSortedReportProducts(
              sourceProducts: allProducts,
              sectorId: _selectedSectorId,
              isArchived: widget.isArchived,
              sortOrder: _sortOrder,
            );
            final totalUnits = reportItems.fold<int>(0, (sum, p) => sum + p.quantity);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740, maxHeight: 740),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.isArchived
                                  ? const Color(0xFFFEF3C7)
                                  : AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.assessment_outlined,
                              color: widget.isArchived
                                  ? const Color(0xFFD97706)
                                  : AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isArchived
                                      ? 'Relatório de Produtos Arquivados'
                                      : 'Relatório Completo de Setor',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Inclui Código Interno, Nome e Quantidade no Estoque',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
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
                      const SizedBox(height: 14),

                      // Seleção de Setor e Ordenação
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1. Escolha o Setor:',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...masterCats.map((mc) {
                                    final selected = _selectedSectorId.toLowerCase() == mc.id.toLowerCase();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        avatar: Icon(
                                          mc.icon,
                                          size: 15,
                                          color: selected ? mc.color : AppColors.textSecondary,
                                        ),
                                        label: Text(mc.name),
                                        selected: selected,
                                        selectedColor: mc.color.withValues(alpha: 0.16),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: selected ? mc.color : AppColors.textPrimary,
                                        ),
                                        onSelected: (_) {
                                          setState(() => _selectedSectorId = mc.id);
                                        },
                                      ),
                                    );
                                  }),
                                  ChoiceChip(
                                    label: const Text('Todos os Setores'),
                                    selected: _selectedSectorId == 'todas',
                                    selectedColor: AppColors.primaryContainer,
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _selectedSectorId == 'todas' ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedSectorId == 'todas' ? AppColors.primaryDark : AppColors.textPrimary,
                                    ),
                                    onSelected: (_) {
                                      setState(() => _selectedSectorId = 'todas');
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '2. Ordenação do Relatório:',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: SectorReportSortOrder.values.map((ord) {
                                final isSel = _sortOrder == ord;
                                return ChoiceChip(
                                  avatar: Icon(
                                    ord == SectorReportSortOrder.byInternalCode
                                        ? Icons.tag
                                        : Icons.sort_by_alpha,
                                    size: 16,
                                    color: isSel ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  label: Text(ord.label),
                                  selected: isSel,
                                  selectedColor: AppColors.primaryContainer,
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? AppColors.primaryDark : AppColors.textPrimary,
                                  ),
                                  onSelected: (_) {
                                    setState(() => _sortOrder = ord);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Barra de Resumo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Setor: $sectorName • ${reportItems.length} produto(s)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Total em estoque: ${NumberFormat('#,###', 'pt_BR').format(totalUnits)} un',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tabela de Visualização Prévia (Cód. Interno | Nome | Qtd.)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 105,
                                      child: Text(
                                        'Cód. Interno',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Nome do Produto',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 85,
                                      child: Text(
                                        'Estoque',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              Expanded(
                                child: reportItems.isEmpty
                                    ? Center(
                                        child: Text(
                                          widget.isArchived
                                              ? 'Nenhum produto arquivado neste setor.'
                                              : 'Nenhum produto encontrado neste setor.',
                                          style: GoogleFonts.inter(color: AppColors.textMuted),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: reportItems.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(height: 1, color: AppColors.border),
                                        itemBuilder: (context, index) {
                                          final p = reportItems[index];
                                          final code = (p.internalCode ?? p.code ?? '').trim();
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 105,
                                                  child: Text(
                                                    code.isEmpty ? '-' : code,
                                                    style: GoogleFonts.robotoMono(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.primaryDark,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    p.name,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 85,
                                                  child: Text(
                                                    '${p.quantity} ${p.unitSymbol}',
                                                    textAlign: TextAlign.right,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: p.quantity > 0
                                                          ? AppColors.stockNormal
                                                          : AppColors.stockZero,
                                                    ),
                                                  ),
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
                      const SizedBox(height: 14),

                      // Botões de Exportação
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fechar'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.table_view_outlined, size: 18),
                            label: const Text('Salvar / Copiar CSV'),
                            onPressed: reportItems.isEmpty
                                ? null
                                : () => _exportCsv(reportItems, sectorName),
                          ),
                          OutlinedButton.icon(
                            icon: _isPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.print_outlined, size: 18),
                            label: Text(_isPrinting ? 'Imprimindo...' : 'Imprimir'),
                            onPressed: (reportItems.isEmpty || _isPrinting || _isExporting)
                                ? null
                                : () => _printPdf(reportItems, sectorName),
                          ),
                          ElevatedButton.icon(
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: Text(_isExporting ? 'Exportando PDF...' : 'Exportar PDF'),
                            onPressed: (reportItems.isEmpty || _isExporting || _isPrinting)
                                ? null
                                : () => _exportPdfFile(reportItems, sectorName),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
