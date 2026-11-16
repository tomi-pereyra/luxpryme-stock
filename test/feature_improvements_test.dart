import 'package:flutter_test/flutter_test.dart';
import 'package:luxpryme_stock/data/models/product_model.dart';
import 'package:luxpryme_stock/data/models/category_model.dart';
import 'package:luxpryme_stock/data/models/stock_movement_model.dart';
import 'package:luxpryme_stock/data/services/inventory_service.dart';

void main() {
  group('Tokenized Unordered Search Tests', () {
    final testProduct = ProductModel(
      id: 'prod_1',
      name: 'MONTAGEM PLACA ELETRONICA FAROL 16 LEDS',
      internalCode: 'MPE-16L',
      manufacturerCode: 'FAROL-LED-16',
      categoryIds: ['cat_1'],
      subcategories: ['Linha Farol', 'Iluminação Automotiva'],
      quantity: 50,
      minQuantity: 10,
    );

    test('Encontra produto com palavras na mesma ordem', () {
      expect(testProduct.matchesSearch('farol 16 leds'), isTrue);
    });

    test('Encontra produto com palavras em ordem invertida/desordenada', () {
      expect(testProduct.matchesSearch('16 leds farol'), isTrue);
      expect(testProduct.matchesSearch('leds montagem farol'), isTrue);
      expect(testProduct.matchesSearch('mpe-16l placa farol'), isTrue);
    });

    test('Encontra produto pelas múltiplas sub-categorias desordenadas', () {
      expect(testProduct.matchesSearch('farol linha'), isTrue);
      expect(testProduct.matchesSearch('automotiva iluminação'), isTrue);
    });

    test('Não encontra quando uma palavra não existe', () {
      expect(testProduct.matchesSearch('farol 32 leds'), isFalse);
      expect(testProduct.matchesSearch('farol resistor'), isFalse);
    });
  });

  group('Category and Multiple Subcategories Model Tests', () {
    test('CategoryModel suporta sub-categorias', () {
      final cat = CategoryModel(
        id: 'cat_smd',
        name: 'Componentes SMD',
        subcategories: ['Resistores', 'Capacitores', 'Diodos'],
      );

      final map = cat.toMap();
      final restored = CategoryModel.fromMap(map);

      expect(restored.subcategories, contains('Resistores'));
      expect(restored.subcategories, contains('Capacitores'));
      expect(restored.subcategories.length, equals(3));
    });

    test('ProductModel serializa e deserializa múltiplas sub-categorias', () {
      final p = ProductModel(
        id: 'p1',
        name: 'Resistor 10k SMD 0805',
        categoryIds: ['cat_smd'],
        subcategories: ['Resistores', 'Precisão 1%', 'Passivos SMD'],
        quantity: 1000,
        minQuantity: 200,
      );

      final map = p.toMap();
      final restored = ProductModel.fromMap(map);

      expect(restored.subcategories.length, equals(3));
      expect(restored.subcategories, contains('Resistores'));
      expect(restored.subcategories, contains('Precisão 1%'));
      expect(restored.subcategories, contains('Passivos SMD'));
      expect(restored.subcategory, equals('Resistores'));
    });
  });

  group('StockMovement Model & Origin Tests', () {
    test('Diferencia movimentação de Carrinho vs Ajuste Direto', () {
      final cartMov = StockMovementModel(
        id: 'mov_1',
        productId: 'prod_1',
        productName: 'Resistor 10k',
        categoryNames: ['SMD'],
        type: 'CART_WITHDRAWAL',
        delta: -10,
        previousQuantity: 100,
        newQuantity: 90,
        operatorName: 'Tomas (PIN: 1234)',
        createdAt: DateTime.now(),
      );

      final directMov = StockMovementModel(
        id: 'mov_2',
        productId: 'prod_1',
        productName: 'Resistor 10k',
        categoryNames: ['SMD'],
        type: 'UNIT_REMOVE',
        delta: -1,
        previousQuantity: 90,
        newQuantity: 89,
        operatorName: 'Administrador (Admin)',
        createdAt: DateTime.now(),
      );

      expect(cartMov.type.startsWith('CART_'), isTrue);
      expect(directMov.type.startsWith('CART_'), isFalse);
    });

    test('toMap com forDatabaseInsert filtra IDs não-UUID para evitar erro PostgreSQL 22P02', () {
      final nonUuidMov = StockMovementModel(
        id: 'mov-1731760000000000',
        productId: 'prod-1234',
        productName: 'Capacitor 100nF',
        categoryNames: ['SMD'],
        delta: 5,
        previousQuantity: 10,
        newQuantity: 15,
        type: 'UNIT_ADD',
        operatorName: 'Tomas Pereyra',
        createdAt: DateTime.now(),
      );

      final insertPayload = nonUuidMov.toMap(forDatabaseInsert: true);
      expect(insertPayload.containsKey('id'), isFalse, reason: 'ID não-UUID deve ser omitido para o Postgres gerar');
      expect(insertPayload['product_id'], isNull, reason: 'product_id não-UUID deve ser null para evitar erro de sintaxe');

      final realUuidMov = StockMovementModel(
        id: '123e4567-e89b-12d3-a456-426614174000',
        productId: '987fcdeb-51a2-43f7-9abc-def012345678',
        productName: 'Resistor 10k',
        categoryNames: ['PTH'],
        delta: -1,
        previousQuantity: 20,
        newQuantity: 19,
        type: 'UNIT_REMOVE',
        operatorName: 'Tomas Pereyra',
        createdAt: DateTime.now(),
      );

      final realPayload = realUuidMov.toMap(forDatabaseInsert: true);
      expect(realPayload['id'], equals('123e4567-e89b-12d3-a456-426614174000'));
      expect(realPayload['product_id'], equals('987fcdeb-51a2-43f7-9abc-def012345678'));
    });
  });

  group('Admin Access Control Tests', () {
    test('Validação de e-mail de administrador configurado', () {
      expect(InventoryService.adminEmail, equals('tomibr20@gmail.com'));
    });
  });
}
