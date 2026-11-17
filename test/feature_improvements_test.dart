import 'package:flutter_test/flutter_test.dart';
import 'package:luxpryme_stock/data/models/product_model.dart';
import 'package:luxpryme_stock/data/models/category_model.dart';
import 'package:luxpryme_stock/data/models/master_category_model.dart';
import 'package:luxpryme_stock/data/models/operator_pin_model.dart';
import 'package:luxpryme_stock/data/models/stock_movement_model.dart';
import 'package:luxpryme_stock/data/models/cart_item_model.dart';
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

  group('Master Category and Operator PIN Scope Tests', () {
    final prodEletronica = ProductModel(
      id: 'prod_elet',
      name: 'Resistor SMD 10k',
      masterCategories: ['eletronica'],
      categoryIds: ['cat_1'],
      quantity: 100,
    );

    final prodProducao = ProductModel(
      id: 'prod_prod',
      name: 'Caixa Plástica Slim 800',
      masterCategories: ['producao'],
      categoryIds: ['cat_2'],
      quantity: 50,
    );

    final prodCompartilhado = ProductModel(
      id: 'prod_comp',
      name: 'Chicote de Interligação Bateria',
      masterCategories: ['eletronica', 'producao'],
      categoryIds: ['cat_1'],
      quantity: 25,
    );

    final prodOutros = ProductModel(
      id: 'prod_outros',
      name: 'Tubo Soldável Tigre 25mm',
      masterCategories: ['outros'],
      categoryIds: ['cat_3'],
      quantity: 10,
    );

    test('PIN de Eletrônica só pode movimentar itens de eletrônica', () {
      final pinElet = OperatorPinModel(
        id: 'pin_elet',
        name: 'Operador SMD',
        pin: '1111',
        masterCategory: 'eletronica',
        createdAt: DateTime.now(),
      );

      expect(pinElet.canModify(prodEletronica), isTrue);
      expect(pinElet.canModify(prodCompartilhado), isTrue);
      expect(pinElet.canModify(prodProducao), isFalse);
      expect(pinElet.canModify(prodOutros), isFalse);
    });

    test('PIN de Produção só pode movimentar itens de produção', () {
      final pinProd = OperatorPinModel(
        id: 'pin_prod',
        name: 'Operador Montagem',
        pin: '2222',
        masterCategory: 'producao',
        createdAt: DateTime.now(),
      );

      expect(pinProd.canModify(prodProducao), isTrue);
      expect(pinProd.canModify(prodCompartilhado), isTrue);
      expect(pinProd.canModify(prodEletronica), isFalse);
      expect(pinProd.canModify(prodOutros), isFalse);
    });

    test('PIN Mestre (todas) pode movimentar qualquer categoria', () {
      final pinMaster = OperatorPinModel(
        id: 'pin_master',
        name: 'Tomas Pereyra',
        pin: '2026',
        masterCategory: 'todas',
        createdAt: DateTime.now(),
      );

      expect(pinMaster.canModify(prodEletronica), isTrue);
      expect(pinMaster.canModify(prodProducao), isTrue);
      expect(pinMaster.canModify(prodCompartilhado), isTrue);
      expect(pinMaster.canModify(prodOutros), isTrue);
    });

    test('Serialização e Deserialização de masterCategories no ProductModel', () {
      final p = ProductModel(
        id: 'p_test',
        name: 'Sensor de Presença IP65',
        masterCategories: ['eletronica', 'producao'],
        categoryIds: ['c1'],
        quantity: 15,
      );

      final map = p.toMap();
      expect(map['master_categories'], equals(['eletronica', 'producao']));

      final restored = ProductModel.fromMap(map);
      expect(restored.masterCategories, equals(['eletronica', 'producao']));
      expect(restored.isEletronica, isTrue);
      expect(restored.isProducao, isTrue);
      expect(restored.isOutros, isFalse);
    });
  });

  group('Dynamic Master Categories Management with Master PIN Tests', () {
    final service = InventoryService.instance;

    test('Serialização e Deserialização do MasterCategoryModel', () {
      final model = MasterCategoryModel(
        id: 'preparacao',
        name: 'Preparação',
        description: 'Setor de corte e preparação de fios e cabos',
        colorHex: '#EA580C',
        iconName: 'build',
      );

      final map = model.toMap();
      expect(map['id'], equals('preparacao'));
      expect(map['name'], equals('Preparação'));
      expect(map['color'], equals('#EA580C'));
      expect(map['icon'], equals('build'));

      final restored = MasterCategoryModel.fromMap(map);
      expect(restored.id, equals('preparacao'));
      expect(restored.name, equals('Preparação'));
      expect(restored.colorHex, equals('#EA580C'));
    });

    test('Criar Categoria Mestre com PIN Mestre (autorizado)', () async {
      final newCat = await service.createMasterCategory(
        name: 'Embalamento e Expedição',
        description: 'Caixas coletivas e embalagens finais',
        colorHex: '#7C3AED',
        iconName: 'all_inbox',
        masterPin: '2026', // PIN Mestre do Tomas
      );

      expect(newCat.id, equals('embalamento_e_expedicao'));
      expect(newCat.name, equals('Embalamento e Expedição'));
      expect(service.masterCategories.any((mc) => mc.id == 'embalamento_e_expedicao'), isTrue);
    });

    test('Rejeitar criação de Categoria Mestre com PIN não-mestre (ex: Eletrônica 1111)', () async {
      expect(
        () => service.createMasterCategory(
          name: 'Pintura',
          masterPin: '1111', // PIN de Eletrônica, não é mestre
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Apenas operadores com PIN Mestre'),
        )),
      );
    });

    test('Modificar Categoria Mestre com PIN Mestre', () async {
      final updated = await service.updateMasterCategory(
        id: 'embalamento_e_expedicao',
        name: 'Embalamento Industrial',
        description: 'Nova descrição atualizada',
        masterPin: '2026',
      );

      expect(updated.name, equals('Embalamento Industrial'));
      expect(service.getMasterCategoryName('embalamento_e_expedicao'), equals('Embalamento Industrial'));
    });

    test('Eliminar Categoria Mestre com PIN Mestre e proteger categoria Outros', () async {
      // Tentar eliminar Outros deve falhar
      expect(
        () => service.deleteMasterCategory(id: 'outros', masterPin: '2026'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('é padrão do sistema e não pode ser excluída'),
        )),
      );

      // Eliminar categoria criada anteriormente com PIN Mestre
      await service.deleteMasterCategory(id: 'embalamento_e_expedicao', masterPin: '2026');
      expect(service.masterCategories.any((mc) => mc.id == 'embalamento_e_expedicao'), isFalse);
    });
  });

  group('Cart Optional Observation / Notes Tests', () {
    test('StockMovementModel suporta campo opcional notes na serialização e deserialização', () {
      final movWithNote = StockMovementModel(
        id: '123e4567-e89b-12d3-a456-426614174000',
        productId: '987fcdeb-51a2-43f7-9abc-def012345678',
        productName: 'Placa Central Farol',
        categoryNames: ['Eletrônica'],
        delta: -5,
        previousQuantity: 50,
        newQuantity: 45,
        type: 'CART_WITHDRAWAL',
        operatorName: 'Tomas Pereyra',
        notes: 'Lote de produção especial #42',
        createdAt: DateTime.now(),
      );

      final map = movWithNote.toMap();
      expect(map['notes'], equals('Lote de produção especial #42'));

      final restored = StockMovementModel.fromMap(map);
      expect(restored.notes, equals('Lote de produção especial #42'));

      // Sem nota
      final movWithoutNote = StockMovementModel(
        id: '123e4567-e89b-12d3-a456-426614174001',
        productId: '987fcdeb-51a2-43f7-9abc-def012345678',
        productName: 'Placa Central Farol',
        categoryNames: ['Eletrônica'],
        delta: 2,
        previousQuantity: 45,
        newQuantity: 47,
        type: 'CART_DEPOSIT',
        operatorName: 'Tomas Pereyra',
        createdAt: DateTime.now(),
      );

      expect(movWithoutNote.toMap().containsKey('notes'), isFalse);
      expect(StockMovementModel.fromMap(movWithoutNote.toMap()).notes, isNull);
    });

    test('checkoutCart registra observação opcional no histórico de movimentação', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final products = await service.fetchProducts();
      final targetProduct = products.first;

      final cartItems = [
        CartItemModel(
          product: targetProduct,
          quantity: 2,
          isWithdrawal: false, // Reposição de 2 unidades
        ),
      ];

      const customNote = 'Entrada emergencial de reposição - OS #99';
      await service.checkoutCart(
        cartItems: cartItems,
        pin: '2026', // PIN Mestre
        notes: customNote,
      );

      final movements = await service.fetchMovements();
      final lastMov = movements.first;

      expect(lastMov.notes, equals(customNote));
      expect(lastMov.delta, equals(2));
      expect(lastMov.type, equals('CART_DEPOSIT'));
    });
  });

  group('Batch Add Products to Master Category (+ Itens) Tests', () {
    test('bulkAddProductsToMasterCategory adiciona múltiplos produtos à categoria mestre com PIN Mestre', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final products = await service.fetchProducts();
      final p1 = products[0];
      final p2 = products[1];

      await service.bulkAddProductsToMasterCategory(
        productIds: [p1.id, p2.id],
        targetMasterCategoryId: 'producao',
        pin: '2026', // PIN Mestre do Tomas
      );

      final updatedProducts = await service.fetchProducts();
      final updatedP1 = updatedProducts.firstWhere((p) => p.id == p1.id);
      final updatedP2 = updatedProducts.firstWhere((p) => p.id == p2.id);

      expect(updatedP1.masterCategories, contains('producao'));
      expect(updatedP2.masterCategories, contains('producao'));
    });

    test('bulkAddProductsToMasterCategory rejeita adição com PIN não-mestre', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final products = await service.fetchProducts();
      final p1 = products.first;

      expect(
        () => service.bulkAddProductsToMasterCategory(
          productIds: [p1.id],
          targetMasterCategoryId: 'eletronica',
          pin: '1111', // PIN de Eletrônica (não é PIN mestre)
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Apenas operadores com PIN Mestre'),
        )),
      );
    });

    test('bulkRemoveProductsFromMasterCategory remove produto da categoria mestre e atribui a outros se vazia', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final products = await service.fetchProducts();
      final p1 = products.first;

      // Primeiro garante que está em producao
      await service.bulkAddProductsToMasterCategory(
        productIds: [p1.id],
        targetMasterCategoryId: 'producao',
        pin: '2026',
      );

      // Agora remove de producao
      await service.bulkRemoveProductsFromMasterCategory(
        productIds: [p1.id],
        targetMasterCategoryId: 'producao',
        pin: '2026',
      );

      final updatedProducts = await service.fetchProducts();
      final updatedP1 = updatedProducts.firstWhere((p) => p.id == p1.id);

      expect(updatedP1.masterCategories.contains('producao'), isFalse);
      expect(updatedP1.masterCategories.isNotEmpty, isTrue);
    });

    test('bulkRemoveProductsFromMasterCategory rejeita remoção com PIN não-mestre', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final products = await service.fetchProducts();
      final p1 = products.first;

      expect(
        () => service.bulkRemoveProductsFromMasterCategory(
          productIds: [p1.id],
          targetMasterCategoryId: 'eletronica',
          pin: '1111', // PIN de Eletrônica, não mestre
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Apenas operadores com PIN Mestre'),
        )),
      );
    });
  });
}
