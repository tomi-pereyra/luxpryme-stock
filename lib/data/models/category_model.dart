class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final List<String> subcategories;
  final List<String> masterCategories; // Setores vinculados explicitamente
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.subcategories = const [],
    this.masterCategories = const [],
    this.createdAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    List<String> subs = [];
    if (map['subcategories'] is List) {
      subs = (map['subcategories'] as List).map((e) => e.toString()).toList();
    }

    List<String> parsedSectors = [];
    if (map['master_categories'] is List) {
      parsedSectors = (map['master_categories'] as List)
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    String? rawDesc = map['description']?.toString();
    String? cleanDesc = rawDesc;
    if (rawDesc != null) {
      final match = RegExp(r'\[setores:([^\]]*)\]').firstMatch(rawDesc);
      if (match != null) {
        if (parsedSectors.isEmpty) {
          final sStr = match.group(1) ?? '';
          parsedSectors = sStr
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        cleanDesc = rawDesc.replaceAll(RegExp(r'\s*\[setores:[^\]]*\]'), '').trim();
        if (cleanDesc.isEmpty) cleanDesc = null;
      }
    }

    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: cleanDesc,
      subcategories: subs,
      masterCategories: parsedSectors,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  /// Gera a descrição serializada para o Supabase preservando a associação de setores sem exigir migração SQL
  String? toSupabaseDescription() {
    final base = description?.trim() ?? '';
    final cleanSectors = masterCategories
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty && s != 'todas')
        .toSet()
        .toList();
    if (cleanSectors.isEmpty) {
      return base.isEmpty ? null : base;
    }
    final tag = '[setores:${cleanSectors.join(",")}]';
    return base.isEmpty ? tag : '$base $tag';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (subcategories.isNotEmpty) 'subcategories': subcategories,
      if (masterCategories.isNotEmpty) 'master_categories': masterCategories,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    List<String>? subcategories,
    List<String>? masterCategories,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      subcategories: subcategories ?? this.subcategories,
      masterCategories: masterCategories ?? this.masterCategories,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
