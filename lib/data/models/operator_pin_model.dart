import 'product_model.dart';

class OperatorPinModel {
  final String id;
  final String name; // Nome do operador ou setor (ex: "Tomas - Supervisor", "Roberto - Linha")
  final String pin;  // Exatamente 4 dígitos
  final String masterCategory; // 'eletronica', 'producao', 'todas'
  final bool isActive;
  final DateTime createdAt;

  const OperatorPinModel({
    required this.id,
    required this.name,
    required this.pin,
    this.masterCategory = 'eletronica',
    this.isActive = true,
    required this.createdAt,
  });

  bool get isMasterPin => masterCategory == 'todas';

  String get masterCategoryLabel {
    switch (masterCategory.toLowerCase()) {
      case 'todas':
        return 'Mestre (Todos os Setores)';
      case 'eletronica':
        return 'Eletrônica';
      case 'producao':
        return 'Produção';
      case 'outros':
        return 'Outros';
      case 'preparacao':
        return 'Preparação';
      case 'embalamento':
        return 'Embalamento';
      default:
        return masterCategory
            .split('_')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  /// Verifica se o operador com este PIN tem permissão para movimentar o produto
  bool canModify(ProductModel product) {
    if (isMasterPin) return true;
    return product.masterCategories.contains(masterCategory.toLowerCase());
  }

  factory OperatorPinModel.fromMap(Map<String, dynamic> map) {
    return OperatorPinModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      pin: map['pin']?.toString() ?? '',
      masterCategory: map['master_category']?.toString().toLowerCase() ?? 'eletronica',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'pin': pin,
      'master_category': masterCategory,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  OperatorPinModel copyWith({
    String? id,
    String? name,
    String? pin,
    String? masterCategory,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return OperatorPinModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      masterCategory: masterCategory ?? this.masterCategory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
