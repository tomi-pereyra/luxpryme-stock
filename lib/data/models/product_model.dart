class ProductModel {
  final String id;
  final String name;
  final String? code;
  final String? internalCode;      // Código Interno
  final String? manufacturerCode;  // Código do Fabricante / Part Number
  final String? barcode;           // Código de Barras
  final List<String> masterCategories; // Categorias Mestres: 'eletronica', 'producao', 'outros'
  final List<String> categoryIds;  // Suporte a múltiplas categorias
  final List<String>? categoryNames; // Nomes resolvidos das categorias
  final List<String> subcategories; // Múltiplas sub-categorias do item
  final int quantity;
  final int minQuantity;
  final String unit;               // Unidade de contagem: 'un', 'kg', 'g', 'm', 'cm', 'L', 'mL'
  final String? location;
  final String? notes;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String archivedTag = '__archived__';
  static const String unitTagPrefix = '__unit:';
  static const String unitTagSuffix = '__';

  static const List<String> supportedUnits = ['un', 'kg', 'g', 'm', 'cm', 'L', 'mL'];

  static String normalizeUnit(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    switch (clean) {
      case 'un':
      case 'und':
      case 'unid':
      case 'unidade':
        return 'un';
      case 'kg':
      case 'quilo':
      case 'quilograma':
      case 'peso':
        return 'kg';
      case 'g':
      case 'gr':
      case 'grama':
        return 'g';
      case 'm':
      case 'mt':
      case 'metro':
        return 'm';
      case 'cm':
      case 'centimetro':
        return 'cm';
      case 'l':
      case 'lt':
      case 'litro':
      case 'volume':
        return 'L';
      case 'ml':
      case 'mililitro':
        return 'mL';
      default:
        return 'un';
    }
  }

  const ProductModel({
    required this.id,
    required this.name,
    this.code,
    this.internalCode,
    this.manufacturerCode,
    this.barcode,
    this.masterCategories = const ['eletronica'],
    required this.categoryIds,
    this.categoryNames,
    this.subcategories = const [],
    String? subcategory,
    required this.quantity,
    this.minQuantity = 10,
    this.unit = 'un',
    this.location,
    this.notes,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  }) : _legacySubcategory = subcategory;

  String get unitSymbol => normalizeUnit(unit);

  String get unitCategory {
    switch (unitSymbol) {
      case 'kg':
      case 'g':
        return 'peso';
      case 'm':
      case 'cm':
        return 'metro';
      case 'L':
      case 'mL':
        return 'volume';
      default:
        return 'unidade';
    }
  }

  String get unitCategoryLabel {
    switch (unitCategory) {
      case 'peso':
        return 'Peso';
      case 'metro':
        return 'Metro';
      case 'volume':
        return 'Volume';
      default:
        return 'Unidade';
    }
  }

  final String? _legacySubcategory;

  // Getter de compatibilidade com subcategoria singular
  String? get subcategory {
    if (subcategories.isNotEmpty) return subcategories.first;
    return _legacySubcategory;
  }

  // Getter de compatibilidade com código anterior
  String get categoryId => categoryIds.isNotEmpty ? categoryIds.first : '';
  String? get categoryName =>
      (categoryNames != null && categoryNames!.isNotEmpty) ? categoryNames!.first : null;

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= minQuantity;

  bool get isEletronica => masterCategories.contains('eletronica');
  bool get isProducao => masterCategories.contains('producao');
  bool get isOutros => masterCategories.contains('outros');

  /// Normaliza textos para busca, convertendo para minúsculas e removendo acentos
  static String normalizeSearchText(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàãâä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìîï]'), 'i');
    s = s.replaceAll(RegExp(r'[óòõôö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[ñ]'), 'n');
    return s;
  }

  /// Pesquisa inteligente por palavras desordenadas em Nome, Cód. Interno, P/N, Cód. Barras, Subcategorias e Notas
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final cleanQuery = normalizeSearchText(query);
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final normName = normalizeSearchText(name);
    final normIntCode = normalizeSearchText(internalCode ?? '');
    final normMfgCode = normalizeSearchText(manufacturerCode ?? '');
    final normCode = normalizeSearchText(code ?? '');
    final normBarcode = normalizeSearchText(barcode ?? '');
    final normSubcats = subcategories.map(normalizeSearchText).join(' ');
    final normSubcat = normalizeSearchText(subcategory ?? '');
    final normLoc = normalizeSearchText(location ?? '');
    final normNotes = normalizeSearchText(notes ?? '');
    final normCatNames = (categoryNames ?? []).map(normalizeSearchText).join(' ');

    final fullText = '$normName $normIntCode $normMfgCode $normCode $normBarcode $normSubcats $normSubcat $normLoc $normNotes $normCatNames';
    final words = fullText.split(RegExp(r"""[\s\-_/\\,.;:()\[\]"'&]+""")).where((w) => w.isNotEmpty).toList();

    return tokens.every((token) {
      // 1. Coincidência direta como palavra completa ou prefixo de palavra
      if (words.any((w) => w == token || w.startsWith(token))) return true;

      // 2. Coincidência em campos de código (P/N, Código Interno, Código Geral ou de Barras)
      if (normIntCode.contains(token) || normMfgCode.contains(token) || normCode.contains(token) || normBarcode.contains(token)) {
        return true;
      }

      // 3. Para termos com 3 ou mais caracteres, permite busca por substring geral
      if (token.length >= 3 && fullText.contains(token)) {
        return true;
      }

      return false;
    });
  }

  /// Calcula a pontuação de relevância (score) para ordenar primeiro as opções de melhor coincidência
  int searchRelevance(String query) {
    if (query.isEmpty) return 0;
    final cleanQuery = normalizeSearchText(query);
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return 0;

    int score = 0;
    final normName = normalizeSearchText(name);
    final normIntCode = normalizeSearchText(internalCode ?? '');
    final normMfgCode = normalizeSearchText(manufacturerCode ?? '');
    final normCode = normalizeSearchText(code ?? '');
    final normBarcode = normalizeSearchText(barcode ?? '');
    final normSubcats = subcategories.map(normalizeSearchText).toList();
    final normSubcat = normalizeSearchText(subcategory ?? '');
    final normNotes = normalizeSearchText(notes ?? '');
    final normLoc = normalizeSearchText(location ?? '');
    final normCatNames = (categoryNames ?? []).map(normalizeSearchText).toList();

    // 1. Coincidência Exata em Código (Código Interno, P/N, Código Geral ou Código de Barras)
    if (normIntCode == cleanQuery || normMfgCode == cleanQuery || normCode == cleanQuery || normBarcode == cleanQuery) {
      score += 200000;
    } else if (normIntCode.startsWith(cleanQuery) || normMfgCode.startsWith(cleanQuery) || normCode.startsWith(cleanQuery)) {
      score += 90000;
    } else if (normIntCode.contains(cleanQuery) || normMfgCode.contains(cleanQuery)) {
      score += 50000;
    }

    // 2. Coincidência no Nome do Produto
    if (normName == cleanQuery) {
      score += 250000; // Nome idêntico ao termo pesquisado
    } else if (normName.startsWith(cleanQuery)) {
      score += 150000; // Nome começa exatamente com o termo pesquisado
    } else {
      final phraseIndex = normName.indexOf(cleanQuery);
      if (phraseIndex != -1) {
        // Frase inteira contida no nome (mais perto do início = maior pontuação)
        score += 80000 + (100 - phraseIndex).clamp(0, 100) * 100;
      }
    }

    // 3. Sequência Consecutiva de Palavras no Nome
    if (tokens.length > 1) {
      int consecutivePairs = 0;
      for (int i = 0; i < tokens.length - 1; i++) {
        final pair = '${tokens[i]} ${tokens[i + 1]}';
        if (normName.contains(pair)) {
          consecutivePairs++;
        }
      }
      score += consecutivePairs * 20000;
    }

    // 4. Análise de Palavras Individuais no Nome
    final nameWords = normName.split(RegExp(r"""[\s\-_/\\,.;:()\[\]"'&]+""")).where((w) => w.isNotEmpty).toList();
    int tokensInName = 0;
    for (final token in tokens) {
      if (nameWords.contains(token)) {
        score += 10000;
        tokensInName++;
      } else if (nameWords.any((w) => w.startsWith(token))) {
        score += 7000;
        tokensInName++;
      } else if (normName.contains(token)) {
        score += 3000;
        tokensInName++;
      }
    }

    // Super Bônus: Todos os termos pesquisados estão presentes no NOME do produto
    if (tokensInName == tokens.length) {
      score += 40000;
    }

    // 5. Coincidência nas Sub-categorias
    for (final sub in normSubcats) {
      if (sub == cleanQuery) {
        score += 25000;
      } else if (sub.contains(cleanQuery)) {
        score += 12000;
      } else {
        for (final token in tokens) {
          if (sub.contains(token)) {
            score += 2000;
          }
        }
      }
    }
    if (normSubcat.isNotEmpty) {
      if (normSubcat == cleanQuery) {
        score += 25000;
      } else if (normSubcat.contains(cleanQuery)) {
        score += 12000;
      }
    }

    // 6. Categorias
    for (final cat in normCatNames) {
      if (cat.contains(cleanQuery)) score += 5000;
    }

    // 7. Observações e Localização
    if (normNotes.contains(cleanQuery)) score += 3000;
    if (normLoc.contains(cleanQuery)) score += 2000;

    // 8. Taxa de Cobertura / Densidade do Nome (menor nome com os mesmos termos ganha prioridade)
    if (normName.isNotEmpty) {
      final coverage = (cleanQuery.length / normName.length).clamp(0.0, 1.0);
      score += (coverage * 8000).toInt();
    }

    return score;
  }

  /// Comparador inteligente por Código Interno (numérico natural + alfanumérico; itens sem código ficam no final em ordem alfabética)
  static int compareByInternalCode(ProductModel a, ProductModel b) {
    final codeA = (a.internalCode ?? a.code ?? '').trim();
    final codeB = (b.internalCode ?? b.code ?? '').trim();

    if (codeA.isEmpty && codeB.isEmpty) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    if (codeA.isEmpty) return 1;
    if (codeB.isEmpty) return -1;

    final intA = int.tryParse(codeA);
    final intB = int.tryParse(codeB);
    if (intA != null && intB != null && intA != intB) {
      return intA.compareTo(intB);
    }

    final partsA = RegExp(r'(\d+|\D+)').allMatches(codeA.toLowerCase()).map((m) => m.group(0)!).toList();
    final partsB = RegExp(r'(\d+|\D+)').allMatches(codeB.toLowerCase()).map((m) => m.group(0)!).toList();
    final minLen = partsA.length < partsB.length ? partsA.length : partsB.length;

    for (int i = 0; i < minLen; i++) {
      final pA = partsA[i];
      final pB = partsB[i];
      if (pA == pB) continue;
      final nA = int.tryParse(pA);
      final nB = int.tryParse(pB);
      if (nA != null && nB != null) {
        if (nA != nB) return nA.compareTo(nB);
      } else {
        return pA.compareTo(pB);
      }
    }

    if (partsA.length != partsB.length) {
      return partsA.length.compareTo(partsB.length);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  factory ProductModel.fromMap(Map<String, dynamic> map,
      {List<String>? categoryNames}) {
    // Categorias Mestres + Flag de Arquivamento + Unidade de Contagem
    bool parsedArchived = map['is_archived'] == true;
    String parsedUnit = map['unit'] != null
        ? normalizeUnit(map['unit'].toString())
        : 'un';
    List<String> parsedMasterCats = [];
    if (map['master_categories'] is List) {
      final rawCats = (map['master_categories'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final raw in rawCats) {
        final lower = raw.toLowerCase();
        if (lower == archivedTag) {
          parsedArchived = true;
        } else if (lower.startsWith(unitTagPrefix) &&
            lower.endsWith(unitTagSuffix) &&
            lower.length > unitTagPrefix.length + unitTagSuffix.length) {
          final extracted = lower.substring(
            unitTagPrefix.length,
            lower.length - unitTagSuffix.length,
          );
          parsedUnit = normalizeUnit(extracted);
        } else {
          parsedMasterCats.add(lower);
        }
      }
    }
    if (parsedMasterCats.isEmpty) {
      parsedMasterCats = ['eletronica'];
    }

    // Suporte tanto para array category_ids quanto para category_id singular
    List<String> parsedCategoryIds = [];
    if (map['category_ids'] is List) {
      parsedCategoryIds = (map['category_ids'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (map['category_id'] != null &&
        map['category_id'].toString().isNotEmpty) {
      parsedCategoryIds = [map['category_id'].toString()];
    }

    // Suporte para múltiplas sub-categorias e compatibilidade com subcategoria única
    List<String> parsedSubcategories = [];
    if (map['subcategories'] is List) {
      parsedSubcategories = (map['subcategories'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (map['subcategory'] != null &&
        map['subcategory'].toString().trim().isNotEmpty) {
      parsedSubcategories = [map['subcategory'].toString().trim()];
    }

    // Se o banco ainda não possuir a coluna subcategories, lê do fallback transparente em notes
    String? rawNotes = map['notes']?.toString();
    String? cleanNotes = rawNotes;
    if (parsedSubcategories.isEmpty && rawNotes != null) {
      final match = RegExp(r'\[subcats?:([^\]]+)\]').firstMatch(rawNotes);
      if (match != null) {
        final subsStr = match.group(1);
        if (subsStr != null && subsStr.trim().isNotEmpty) {
          if (subsStr.contains(';;')) {
            parsedSubcategories = subsStr
                .split(';;')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          } else {
            parsedSubcategories = subsStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
        cleanNotes = rawNotes.replaceAll(RegExp(r'\s*\[subcats?:[^\]]*\]'), '').trim();
        if (cleanNotes.isEmpty) cleanNotes = null;
      }
    }

    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString(),
      internalCode: map['internal_code']?.toString(),
      manufacturerCode: map['manufacturer_code']?.toString(),
      barcode: map['barcode']?.toString(),
      masterCategories: parsedMasterCats,
      categoryIds: parsedCategoryIds,
      categoryNames: categoryNames,
      subcategories: parsedSubcategories,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (map['min_quantity'] as num?)?.toInt() ?? 10,
      unit: parsedUnit,
      location: map['location']?.toString(),
      notes: cleanNotes,
      isArchived: parsedArchived,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  static final RegExp uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Map<String, dynamic> toMap({
    bool forDatabaseInsert = false,
    bool forSupabase = false,
  }) {
    final isValidId = uuidRegex.hasMatch(id);
    final validCategoryIds = categoryIds.where((c) => uuidRegex.hasMatch(c)).toList();
    final validCategoryId = (categoryId.isNotEmpty && uuidRegex.hasMatch(categoryId))
        ? categoryId
        : (validCategoryIds.isNotEmpty ? validCategoryIds.first : null);

    final cleanSectors = masterCategories
        .where((c) =>
            c != archivedTag &&
            !(c.toLowerCase().startsWith(unitTagPrefix) &&
                c.toLowerCase().endsWith(unitTagSuffix)))
        .toList();
    final effectiveSectors = cleanSectors.isEmpty ? <String>['eletronica'] : cleanSectors;
    final normalizedUnit = normalizeUnit(unit);
    final serializedMasterCats = <String>[
      ...effectiveSectors,
      if (isArchived) archivedTag,
      if (normalizedUnit != 'un') '$unitTagPrefix${normalizedUnit.toLowerCase()}$unitTagSuffix',
    ];

    final map = <String, dynamic>{
      'name': name,
      if (code != null && code!.isNotEmpty) 'code': code,
      if (internalCode != null && internalCode!.isNotEmpty) 'internal_code': internalCode,
      if (manufacturerCode != null && manufacturerCode!.isNotEmpty) 'manufacturer_code': manufacturerCode,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'master_categories': serializedMasterCats,
      'subcategories': subcategories,
      if (subcategory != null) 'subcategory': subcategory,
      'quantity': quantity,
      'min_quantity': minQuantity,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (!forDatabaseInsert && !forSupabase) ...{
        'is_archived': isArchived,
        'unit': normalizedUnit,
      },
    };

    if (forDatabaseInsert) {
      if (isValidId) {
        map['id'] = id;
      }
      if (validCategoryId != null) {
        map['category_id'] = validCategoryId;
      }
      if (validCategoryIds.isNotEmpty) {
        map['category_ids'] = validCategoryIds;
      }
    } else if (forSupabase) {
      map['category_ids'] = validCategoryIds;
      map['category_id'] = validCategoryId;
    } else {
      if (id.isNotEmpty) map['id'] = id;
      map['category_ids'] = categoryIds;
      if (categoryIds.isNotEmpty) map['category_id'] = categoryIds.first;
    }

    return map;
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? code,
    String? internalCode,
    String? manufacturerCode,
    String? barcode,
    List<String>? masterCategories,
    List<String>? categoryIds,
    List<String>? categoryNames,
    List<String>? subcategories,
    String? subcategory,
    int? quantity,
    int? minQuantity,
    String? unit,
    String? location,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    List<String> finalSubcats = subcategories ?? this.subcategories;
    if (subcategory != null && subcategories == null) {
      finalSubcats = [subcategory];
    }

    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      internalCode: internalCode ?? this.internalCode,
      manufacturerCode: manufacturerCode ?? this.manufacturerCode,
      barcode: barcode ?? this.barcode,
      masterCategories: masterCategories ?? this.masterCategories,
      categoryIds: categoryIds ?? this.categoryIds,
      categoryNames: categoryNames ?? this.categoryNames,
      subcategories: finalSubcats,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      unit: unit != null ? normalizeUnit(unit) : this.unit,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
