class ProductModel {
  final String id;
  final String name;
  final String? code;
  final String? internalCode;      // Código Interno
  final String? manufacturerCode;  // Código do Fabricante / Part Number
  final List<String> categoryIds;  // Suporte a múltiplas categorias
  final List<String>? categoryNames; // Nomes resolvidos das categorias
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
    required this.quantity,
    this.minQuantity = 10,
    this.location,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // Getter de compatibilidade com código anterior
  String get categoryId => categoryIds.isNotEmpty ? categoryIds.first : '';
  String? get categoryName =>
      (categoryNames != null && categoryNames!.isNotEmpty) ? categoryNames!.first : null;

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= minQuantity;

  /// Pesquisa inteligente: verifica Nome, Código Interno, Código do Fabricante ou Código Geral
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();

    final matchesName = name.toLowerCase().contains(q);
    final matchesInternal =
        internalCode != null && internalCode!.toLowerCase().contains(q);
    final matchesManufacturer =
        manufacturerCode != null && manufacturerCode!.toLowerCase().contains(q);
    final matchesGeneralCode = code != null && code!.toLowerCase().contains(q);
    final matchesLoc = location != null && location!.toLowerCase().contains(q);

    return matchesName ||
        matchesInternal ||
        matchesManufacturer ||
        matchesGeneralCode ||
        matchesLoc;
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

    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString(),
      internalCode: map['internal_code']?.toString(),
      manufacturerCode: map['manufacturer_code']?.toString(),
      categoryIds: parsedCategoryIds,
      categoryNames: categoryNames,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (map['min_quantity'] as num?)?.toInt() ?? 10,
      location: map['location']?.toString(),
      notes: map['notes']?.toString(),
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
    int? quantity,
    int? minQuantity,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      internalCode: internalCode ?? this.internalCode,
      manufacturerCode: manufacturerCode ?? this.manufacturerCode,
      categoryIds: categoryIds ?? this.categoryIds,
      categoryNames: categoryNames ?? this.categoryNames,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
