class StockMovementModel {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final String id;
  final String productId;
  final String productName;
  final String? productCode;
  final String? internalCode;
  final String? manufacturerCode;
  final List<String> categoryNames;
  final int delta; // Positivo para entrada, negativo para saída
  final int previousQuantity;
  final int newQuantity;
  final String type; // 'UNIT_QUICK', 'CART_WITHDRAWAL', 'CART_DEPOSIT', 'MANUAL_EDIT'
  final String operatorName;
  final String? pinUsed;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productCode,
    this.internalCode,
    this.manufacturerCode,
    required this.categoryNames,
    required this.delta,
    required this.previousQuantity,
    required this.newQuantity,
    required this.type,
    required this.operatorName,
    this.pinUsed,
    required this.createdAt,
  });

  bool get isEntry => delta > 0;
  bool get isExit => delta < 0;

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedCats = [];
    if (map['category_names'] is List) {
      parsedCats = (map['category_names'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return StockMovementModel(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      productCode: map['product_code']?.toString(),
      internalCode: map['internal_code']?.toString(),
      manufacturerCode: map['manufacturer_code']?.toString(),
      categoryNames: parsedCats,
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      previousQuantity: (map['previous_quantity'] as num?)?.toInt() ?? 0,
      newQuantity: (map['new_quantity'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'UNIT_QUICK',
      operatorName: map['operator_name']?.toString() ?? 'Operador',
      pinUsed: map['pin_used']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({bool forDatabaseInsert = false}) {
    final isValidId = _uuidRegex.hasMatch(id);
    final isValidProductId = _uuidRegex.hasMatch(productId);

    final map = <String, dynamic>{
      'product_name': productName,
      if (productCode != null && productCode!.isNotEmpty) 'product_code': productCode,
      if (internalCode != null && internalCode!.isNotEmpty) 'internal_code': internalCode,
      if (manufacturerCode != null && manufacturerCode!.isNotEmpty) 'manufacturer_code': manufacturerCode,
      'category_names': categoryNames,
      'delta': delta,
      'previous_quantity': previousQuantity,
      'new_quantity': newQuantity,
      'type': type,
      'operator_name': operatorName,
      if (pinUsed != null && pinUsed!.isNotEmpty) 'pin_used': pinUsed,
      'created_at': createdAt.toIso8601String(),
    };

    if (forDatabaseInsert) {
      // Para o banco de dados Supabase:
      // Só envia id se for um UUID válido. Se não for, omite para o Postgres gerar com uuid_generate_v4()!
      if (isValidId) {
        map['id'] = id;
      }
      // Só envia product_id se for um UUID válido para não violar a FK e o tipo UUID
      map['product_id'] = isValidProductId ? productId : null;
    } else {
      if (id.isNotEmpty) map['id'] = id;
      map['product_id'] = productId;
    }

    return map;
  }
}
