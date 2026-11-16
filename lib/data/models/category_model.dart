class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final List<String> subcategories;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.subcategories = const [],
    this.createdAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    List<String> subs = [];
    if (map['subcategories'] is List) {
      subs = (map['subcategories'] as List).map((e) => e.toString()).toList();
    }

    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      subcategories: subs,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (subcategories.isNotEmpty) 'subcategories': subcategories,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? subcategories,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subcategories: subcategories ?? this.subcategories,
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
