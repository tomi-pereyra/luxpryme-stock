class ProductModel {
  final String id;
  final String name;
  final String? code;
  final String? internalCode;      // Código Interno
  final String? manufacturerCode;  // Código do Fabricante / Part Number
  final List<String> categoryIds;  // Suporte a múltiplas categorias
  final List<String>? categoryNames; // Nomes resolvidos das categorias
  final List<String> subcategories; // Múltiplas sub-categorias do item
  final int quantity;
  final int minQuantity;
  final String? location;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    this.code,
    this.internalCode,
    this.manufacturerCode,
    required this.categoryIds,
    this.categoryNames,
    this.subcategories = const [],
    String? subcategory,
    required this.quantity,
    this.minQuantity = 10,
    this.location,
    this.notes,
    this.createdAt,
    this.updatedAt,
  }) : _legacySubcategory = subcategory;

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

  /// Pesquisa inteligente por palavras desordenadas em Nome, Cód. Interno, P/N, Subcategorias e Notas
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final buffer = StringBuffer();
    buffer.write(name.toLowerCase());
    buffer.write(' ');
    if (internalCode != null) buffer.write('${internalCode!.toLowerCase()} ');
    if (manufacturerCode != null) buffer.write('${manufacturerCode!.toLowerCase()} ');
    if (code != null) buffer.write('${code!.toLowerCase()} ');
    if (subcategories.isNotEmpty) buffer.write('${subcategories.join(' ').toLowerCase()} ');
    if (subcategory != null) buffer.write('${subcategory!.toLowerCase()} ');
    if (location != null) buffer.write('${location!.toLowerCase()} ');
    if (notes != null) buffer.write('${notes!.toLowerCase()} ');
    if (categoryNames != null) {
      buffer.write('${categoryNames!.join(' ').toLowerCase()} ');
    }
    final fullText = buffer.toString();

    // Todas as palavras digitadas devem estar presentes no produto (não importa a ordem)
    return tokens.every((token) => fullText.contains(token));
  }

  factory ProductModel.fromMap(Map<String, dynamic> map,
      {List<String>? categoryNames}) {
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
      categoryIds: parsedCategoryIds,
      categoryNames: categoryNames,
      subcategories: parsedSubcategories,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (map['min_quantity'] as num?)?.toInt() ?? 10,
      location: map['location']?.toString(),
      notes: cleanNotes,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (code != null) 'code': code,
      if (internalCode != null) 'internal_code': internalCode,
      if (manufacturerCode != null) 'manufacturer_code': manufacturerCode,
      'category_ids': categoryIds,
      'subcategories': subcategories,
      if (subcategory != null) 'subcategory': subcategory,
      // Salva também o primeiro como category_id para compatibilidade
      if (categoryIds.isNotEmpty) 'category_id': categoryIds.first,
      'quantity': quantity,
      'min_quantity': minQuantity,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? code,
    String? internalCode,
    String? manufacturerCode,
    List<String>? categoryIds,
    List<String>? categoryNames,
    List<String>? subcategories,
    String? subcategory,
    int? quantity,
    int? minQuantity,
    String? location,
    String? notes,
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
      categoryIds: categoryIds ?? this.categoryIds,
      categoryNames: categoryNames ?? this.categoryNames,
      subcategories: finalSubcats,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
