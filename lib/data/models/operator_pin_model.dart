class OperatorPinModel {
  final String id;
  final String name; // Nome do operador ou setor (ex: "Tomas - Supervisor", "Roberto - Linha")
  final String pin;  // Exatamente 4 dígitos
  final bool isActive;
  final DateTime createdAt;

  const OperatorPinModel({
    required this.id,
    required this.name,
    required this.pin,
    this.isActive = true,
    required this.createdAt,
  });

  factory OperatorPinModel.fromMap(Map<String, dynamic> map) {
    return OperatorPinModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      pin: map['pin']?.toString() ?? '',
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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  OperatorPinModel copyWith({
    String? id,
    String? name,
    String? pin,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return OperatorPinModel(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
