class StockConflictModel {
  final String id;
  final String productId;
  final String productName;
  final String? productCode;
  final String? internalCode;
  final int currentQuantity; // Saldo que resultou negativo (ex: -3)
  final int deficitAmount; // Quantidade necessária para zerar (ex: 3)
  final String reason;
  final DateTime detectedAt;

  const StockConflictModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productCode,
    this.internalCode,
    required this.currentQuantity,
    required this.deficitAmount,
    required this.reason,
    required this.detectedAt,
  });

  factory StockConflictModel.fromMap(Map<String, dynamic> map) {
    return StockConflictModel(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      productCode: map['product_code']?.toString(),
      internalCode: map['internal_code']?.toString(),
      currentQuantity: (map['current_quantity'] as num?)?.toInt() ?? 0,
      deficitAmount: (map['deficit_amount'] as num?)?.toInt() ?? 0,
      reason: map['reason']?.toString() ?? 'Saldo negativo detectado após sincronização',
      detectedAt: map['detected_at'] != null
          ? DateTime.tryParse(map['detected_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      if (productCode != null) 'product_code': productCode,
      if (internalCode != null) 'internal_code': internalCode,
      'current_quantity': currentQuantity,
      'deficit_amount': deficitAmount,
      'reason': reason,
      'detected_at': detectedAt.toIso8601String(),
    };
  }
}
