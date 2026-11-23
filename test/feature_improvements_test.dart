import 'package:flutter_test/flutter_test.dart';
import 'package:luxpryme_stock/data/models/product_model.dart';
import 'package:luxpryme_stock/data/models/category_model.dart';
import 'package:luxpryme_stock/data/models/master_category_model.dart';
import 'package:luxpryme_stock/data/models/operator_pin_model.dart';
import 'package:luxpryme_stock/data/models/stock_conflict_model.dart';
import 'package:luxpryme_stock/data/models/stock_movement_model.dart';
import 'package:luxpryme_stock/data/models/cart_item_model.dart';
import 'package:luxpryme_stock/data/services/inventory_service.dart';
import 'package:luxpryme_stock/data/services/local_cache_service.dart';

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

    test('Busca ignora acentos (diacríticos) de forma bidirecional', () {
      expect(testProduct.matchesSearch('eletronica farol'), isTrue);
      expect(testProduct.matchesSearch('eletrônica farol'), isTrue);
      expect(testProduct.matchesSearch('iluminacao automotiva'), isTrue);
    });

    test('Melhor coincidência de busca: "placa eletronica slim ac" prioriza o produto exato no topo', () {
      const bestMatch = ProductModel(
        id: 'p1',
        name: 'PLACA ELETRONICA SLIM AC 1400 LUMENS (SLIM AC REV01)',
        categoryIds: ['cat_placas'],
        quantity: 82,
      );

      const secondMatch = ProductModel(
        id: 'p2',
        name: 'MONTAGEM PLACA ELETRONICA SLIM 1000 18 LEDS 12/24VCA',
        categoryIds: ['cat_montagem'],
        quantity: 10,
      );

      const thirdMatch = ProductModel(
        id: 'p3',
        name: 'CIRCUITO IMPRESSO SLIM AC (SLIM AC 7.14 REV01)',
        categoryIds: ['cat_pcb'],
        categoryNames: ['Placa Eletrônica'],
        quantity: 5,
      );

      const fourthMatch = ProductModel(
        id: 'p4',
        name: 'INDUTOR PTH SLIM AC (8X8)',
        categoryIds: ['cat_indutores'],
        notes: 'Placa eletronica slim ac',
        quantity: 20,
      );

      const query = 'placa eletronica slim ac';

      final score1 = bestMatch.searchRelevance(query);
      final score2 = secondMatch.searchRelevance(query);
      final score3 = thirdMatch.searchRelevance(query);
      final score4 = fourthMatch.searchRelevance(query);

      // A melhor coincidência deve ter pontuação muito maior que os outros
      expect(score1, greaterThan(score2));
      expect(score1, greaterThan(score3));
      expect(score1, greaterThan(score4));

      // Ordenando lista mista por relevância decrescente
      final list = [fourthMatch, secondMatch, thirdMatch, bestMatch];
      list.sort((a, b) => b.searchRelevance(query).compareTo(a.searchRelevance(query)));

      expect(list.first.id, equals('p1'));
      expect(list.first.name, contains('PLACA ELETRONICA SLIM AC'));
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

    test('Rejeitar criação de Categoria Mestre com PIN não-mestre (ex: Eletrônica 1830)', () async {
      expect(
        () => service.createMasterCategory(
          name: 'Pintura',
          masterPin: '1830', // PIN de Eletrônica, não é mestre
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
          contains('é padrão do sistema e não pode ser excluído'),
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

      // Garante produtos de teste disponíveis
      await service.createProduct(ProductModel(
        id: 'prod_batch_test_1',
        name: 'Item Teste Batch 1',
        categoryIds: ['cat_1'],
        masterCategories: ['eletronica'],
        quantity: 10,
      ));
      await service.createProduct(ProductModel(
        id: 'prod_batch_test_2',
        name: 'Item Teste Batch 2',
        categoryIds: ['cat_1'],
        masterCategories: ['eletronica'],
        quantity: 10,
      ));

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

  group('Offline-First LocalCacheService & Conflict Resolution Tests', () {
    test('LocalCacheService salva e recupera catálogo local de produtos', () async {
      final cache = LocalCacheService.instance;
      final testProducts = [
        ProductModel(
          id: 'test_offline_1',
          name: 'Produto Teste Offline 1',
          categoryIds: ['cat_1'],
          masterCategories: ['eletronica'],
          quantity: 45,
        ),
        ProductModel(
          id: 'test_offline_2',
          name: 'Produto Teste Offline 2',
          categoryIds: ['cat_2'],
          masterCategories: ['producao'],
          quantity: -3,
        ),
      ];

      await cache.saveProducts(testProducts);
      final loaded = await cache.loadProducts();

      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      expect(loaded.first.id, equals('test_offline_1'));
      expect(loaded.first.quantity, equals(45));
      expect(loaded.last.quantity, equals(-3));
    });

    test('LocalCacheService gerencia fila offline pendente e limpeza', () async {
      final cache = LocalCacheService.instance;
      await cache.clearPendingSyncActions();

      await cache.queueSyncAction({
        'action_type': 'quick_adjust',
        'product_id': 'test_p1',
        'new_quantity': 20,
      });

      final queue = await cache.loadPendingSyncActions();
      expect(queue.length, equals(1));
      expect(queue.first['action_type'], equals('quick_adjust'));
      expect(queue.first['product_id'], equals('test_p1'));

      await cache.clearPendingSyncActions();
      final cleared = await cache.loadPendingSyncActions();
      expect(cleared.isEmpty, isTrue);
    });

    test('StockConflictModel serializa e deserializa conflito de saldo negativo', () {
      final conflict = StockConflictModel(
        id: 'conf_1',
        productId: 'prod_99',
        productName: 'Resistor 10k',
        productCode: 'R10K',
        internalCode: 'INT-99',
        currentQuantity: -4,
        deficitAmount: 4,
        reason: 'Conflito de sincronização simultânea',
        detectedAt: DateTime(2026, 11, 17, 10, 0),
      );

      final map = conflict.toMap();
      final restored = StockConflictModel.fromMap(map);

      expect(restored.id, equals('conf_1'));
      expect(restored.productId, equals('prod_99'));
      expect(restored.currentQuantity, equals(-4));
      expect(restored.deficitAmount, equals(4));
    });

    test('InventoryService resolve conflito redefinindo contagem real com PIN Mestre', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      // Produto que ficou com saldo negativo após saídas simultâneas
      final pConflict = ProductModel(
        id: 'prod_neg_test',
        name: 'Componente Conflito Teste',
        categoryIds: ['cat_1'],
        masterCategories: ['eletronica'],
        quantity: -5,
      );

      // Salva no cache local como ocorreria após sincronização
      await LocalCacheService.instance.saveProducts([pConflict]);

      // Salva conflito correspondente
      final conflict = StockConflictModel(
        id: 'conflict-prod_neg_test',
        productId: pConflict.id,
        productName: pConflict.name,
        currentQuantity: -5,
        deficitAmount: 5,
        reason: 'Teste de saldo negativo',
        detectedAt: DateTime.now(),
      );
      await LocalCacheService.instance.saveConflicts([conflict]);
      await service.initLocalCache();

      expect(service.activeConflicts.any((c) => c.productId == pConflict.id), isTrue);

      // Resolução 1: Informa saldo real de 12 un com PIN Mestre (2026)
      await service.resolveConflictSetStock(
        conflictId: conflict.id,
        productId: pConflict.id,
        newQuantity: 12,
        masterPin: '2026',
        note: 'Contagem física real realizada',
      );

      // Verifica que o conflito foi removido
      expect(service.activeConflicts.any((c) => c.productId == pConflict.id), isFalse);

      // Verifica que o saldo foi corrigido para 12
      final products = await service.fetchProducts();
      final corrected = products.firstWhere((p) => p.id == pConflict.id);
      expect(corrected.quantity, equals(12));
    });

    test('InventoryService rejeita resolução de conflito com PIN não-mestre', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      expect(
        () => service.resolveConflictSetStock(
          conflictId: 'fake_conflict',
          productId: 'fake_prod',
          newQuantity: 0,
          masterPin: '1830', // PIN de operador comum, não mestre (Roberto)
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Apenas operadores com PIN Mestre'),
        )),
      );
    });

    test('InventoryService permite dispensar notificação de conflito', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final conflict = StockConflictModel(
        id: 'conflict-to-dismiss',
        productId: 'prod_disp',
        productName: 'Item para Dispensar',
        currentQuantity: -1,
        deficitAmount: 1,
        reason: 'Teste de descarte',
        detectedAt: DateTime.now(),
      );
      await LocalCacheService.instance.saveConflicts([conflict]);
      await service.initLocalCache();

      expect(service.activeConflicts.any((c) => c.id == 'conflict-to-dismiss'), isTrue);

      await service.dismissConflict('conflict-to-dismiss');
      expect(service.activeConflicts.any((c) => c.id == 'conflict-to-dismiss'), isFalse);
    });
  });

  group('Product Creation and Persistence Bug Fix Tests', () {
    test('ProductModel.toMap(forDatabaseInsert: true) filtra IDs não-UUID para o PostgreSQL gerar UUID nativo e evitar erro 22P02', () {
      final nonUuidProd = ProductModel(
        id: 'prod-1732688000000',
        name: 'Placa Central Farol V2',
        masterCategories: ['eletronica'],
        categoryIds: ['cat-smd'],
        quantity: 10,
      );

      final insertPayload = nonUuidProd.toMap(forDatabaseInsert: true);
      expect(insertPayload.containsKey('id'), isFalse,
          reason: 'ID não-UUID deve ser omitido para o PostgreSQL gerar com uuid_generate_v4()');

      final realUuidProd = ProductModel(
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Placa Central Farol V2',
        masterCategories: ['eletronica'],
        categoryIds: ['cat-smd'],
        quantity: 10,
      );

      final realPayload = realUuidProd.toMap(forDatabaseInsert: true);
      expect(realPayload['id'], equals('123e4567-e89b-12d3-a456-426614174000'));
    });

    test('ProductModel.toMap(forDatabaseInsert: true) filtra category_ids não-UUID para evitar erro de tipo no PostgreSQL', () {
      final prodWithLegacyCats = ProductModel(
        id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Resistor 1k SMD',
        masterCategories: ['eletronica'],
        categoryIds: ['cat-smd', '987fcdeb-51a2-43f7-9abc-def012345678'],
        quantity: 50,
      );

      final payload = prodWithLegacyCats.toMap(forDatabaseInsert: true);
      final validCatIds = payload['category_ids'] as List;
      expect(validCatIds.length, equals(1));
      expect(validCatIds.first, equals('987fcdeb-51a2-43f7-9abc-def012345678'));
      expect(payload['category_id'], equals('987fcdeb-51a2-43f7-9abc-def012345678'));
    });

    test('createProduct insere produto e mantém no catálogo local sem sumir', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final newProd = ProductModel(
        id: '',
        name: 'Novo Sensor Luxpryme 2026',
        internalCode: 'SENS-2026',
        masterCategories: ['eletronica'],
        categoryIds: ['cat-smd'],
        quantity: 25,
      );

      await service.createProduct(newProd, pin: '2026');

      final products = await service.fetchProducts();
      final created = products.where((p) => p.name == 'Novo Sensor Luxpryme 2026');
      expect(created.isNotEmpty, isTrue);
      expect(created.first.quantity, equals(25));
    });

    test('updateProduct e quickAdjustUnit atualizam catálogo local instantaneamente (0ms)', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final testProd = ProductModel(
        id: 'prod-local-instant-1',
        name: 'Componente Instantaneo Teste',
        internalCode: 'INST-001',
        masterCategories: ['eletronica'],
        categoryIds: ['cat-smd'],
        quantity: 10,
      );

      await service.createProduct(testProd, pin: '2026');

      // Update product instantâneo
      final updatedProd = testProd.copyWith(name: 'Componente Modificado Instantaneo', quantity: 15);
      await service.updateProduct(updatedProd);

      var products = await service.fetchProducts();
      var found = products.firstWhere((p) => p.id == 'prod-local-instant-1');
      expect(found.name, equals('Componente Modificado Instantaneo'));
      expect(found.quantity, equals(15));

      // Quick adjust unit (+1 / -1)
      await service.quickAdjustUnit(product: found, delta: 1, pin: '2026');
      products = await service.fetchProducts();
      found = products.firstWhere((p) => p.id == 'prod-local-instant-1');
      expect(found.quantity, equals(16));
    });

    test('validatePin valida PIN localmente a partir da memória/cache em 0ms e atribui nomes corretos', () async {
      final service = InventoryService.instance;
      
      // Claumir (PIN: 2026)
      final opClaumir = await service.validatePin('2026');
      expect(opClaumir, isNotNull);
      expect(opClaumir!.name, contains('Claumir'));
      expect(opClaumir.isMasterPin, isTrue);

      // Tomas (PIN: 4464)
      final opTomas = await service.validatePin('4464');
      expect(opTomas, isNotNull);
      expect(opTomas!.name, contains('Tomas'));
      expect(opTomas.isMasterPin, isTrue);

      // PIN inválido
      final invalid = await service.validatePin('9999');
      expect(invalid, isNull);
    });

    test('Ajustes e operações sem PIN não são atribuídos a Tomas Pereyra', () async {
      final service = InventoryService.instance;
      final testProd = const ProductModel(
        id: 'prod-no-pin-test',
        name: 'Item Sem PIN',
        categoryIds: ['cat-1'],
        masterCategories: ['eletronica'],
        quantity: 10,
      );
      await service.createProduct(testProd); // Sem PIN

      final movements = await service.fetchMovements();
      final creationMov = movements.firstWhere((m) => m.productId == 'prod-no-pin-test');
      expect(creationMov.operatorName, isNot(contains('Tomas Pereyra')));
      expect(creationMov.operatorName, equals('Operador (Sem PIN)'));

      // Ajuste unitário sem PIN (+1)
      await service.quickAdjustUnit(product: testProd, delta: 1); // Sem PIN
      final updatedMovements = await service.fetchMovements();
      final unitMov = updatedMovements.firstWhere((m) => m.productId == 'prod-no-pin-test' && m.delta == 1);
      expect(unitMov.operatorName, isNot(contains('Tomas Pereyra')));
      expect(unitMov.operatorName, equals('Ajuste Direto (+/-)'));
    });

    test('Operações com PIN do Claumir (2026) são atribuídas ao Claumir no histórico', () async {
      final service = InventoryService.instance;
      final testProd = const ProductModel(
        id: 'prod-claumir-test',
        name: 'Item Claumir',
        categoryIds: ['cat-1'],
        masterCategories: ['eletronica'],
        quantity: 5,
      );
      await service.createProduct(testProd, pin: '2026');

      final movements = await service.fetchMovements();
      final mov = movements.firstWhere((m) => m.productId == 'prod-claumir-test');
      expect(mov.operatorName, contains('Claumir'));
      expect(mov.operatorName, isNot(contains('Tomas')));
    });
  });

  group('Lixeira de Produtos e Restauração Tests', () {
    test('LocalCacheService salva e carrega lista de lixeira', () async {
      final cache = LocalCacheService.instance;
      final dummyTrash = [
        const ProductModel(
          id: 'trash-prod-1',
          name: 'Item Lixeira 1',
          categoryIds: ['cat-1'],
          masterCategories: ['eletronica'],
          quantity: 12,
        ),
        const ProductModel(
          id: 'trash-prod-2',
          name: 'Item Lixeira 2',
          categoryIds: ['cat-2'],
          masterCategories: ['producao'],
          quantity: 5,
        ),
      ];

      await cache.saveTrash(dummyTrash);
      final loaded = await cache.loadTrash();

      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      expect(loaded.first.name, equals('Item Lixeira 1'));
      expect(loaded.last.name, equals('Item Lixeira 2'));
    });

    test('deleteProduct move produto para a lixeira e restoreProduct recupera o item', () async {
      final service = InventoryService.instance;
      service.setMode(localMode: true);

      final testProd = ProductModel(
        id: 'prod-trash-test-99',
        name: 'Transistor Lixeira Teste',
        internalCode: 'TR-999',
        manufacturerCode: 'PN-999',
        categoryIds: ['cat-smd'],
        masterCategories: ['eletronica'],
        quantity: 30,
      );

      await service.createProduct(testProd, pin: '2026');

      // 1. Exclui o produto (move para a lixeira)
      await service.deleteProduct(testProd.id, pin: '2026');

      // Verifica se sumiu dos produtos ativos
      final activeProducts = await service.fetchProducts();
      expect(activeProducts.any((p) => p.id == testProd.id), isFalse);

      // Verifica se está presente na lixeira
      final trashList = service.currentTrashProducts;
      expect(trashList.any((p) => p.id == testProd.id), isTrue);
      final inTrash = trashList.firstWhere((p) => p.id == testProd.id);
      expect(inTrash.quantity, equals(30));

      // 2. Restaura o produto da lixeira
      final restored = await service.restoreProduct(testProd.id, pin: '2026');
      expect(restored.id, equals(testProd.id));
      expect(restored.name, equals(testProd.name));

      // Verifica se voltou aos produtos ativos e saiu da lixeira
      final activeAfterRestore = await service.fetchProducts();
      expect(activeAfterRestore.any((p) => p.id == testProd.id), isTrue);

      final trashAfterRestore = service.currentTrashProducts;
      expect(trashAfterRestore.any((p) => p.id == testProd.id), isFalse);
    });
  });

  group('Histórico de Movimentações: Agrupamento no Mesmo Momento Tests', () {
    test('Agrupa ajustes unitários (+ e -) consecutivos do mesmo operador em janela curta', () {
      final now = DateTime(2026, 11, 19, 14, 30, 0);

      final List<StockMovementModel> movements = [
        StockMovementModel(
          id: 'mov-1',
          productId: 'p1',
          productName: 'Resistor 10k',
          categoryNames: const ['Eletrônica'],
          delta: 1,
          previousQuantity: 10,
          newQuantity: 11,
          type: 'UNIT_ADD',
          operatorName: 'Tomas Pereyra',
          createdAt: now,
        ),
        StockMovementModel(
          id: 'mov-2',
          productId: 'p1',
          productName: 'Resistor 10k',
          categoryNames: const ['Eletrônica'],
          delta: 1,
          previousQuantity: 11,
          newQuantity: 12,
          type: 'UNIT_ADD',
          operatorName: 'Tomas Pereyra',
          createdAt: now.add(const Duration(seconds: 15)),
        ),
        StockMovementModel(
          id: 'mov-3',
          productId: 'p2',
          productName: 'Capacitor 100uF',
          categoryNames: const ['Eletrônica'],
          delta: -1,
          previousQuantity: 50,
          newQuantity: 49,
          type: 'UNIT_REMOVE',
          operatorName: 'Tomas Pereyra',
          createdAt: now.add(const Duration(seconds: 30)),
        ),
        // Movimentação de carrinho ou outro operador (não deve agrupar)
        StockMovementModel(
          id: 'mov-4',
          productId: 'p3',
          productName: 'LED Verde',
          categoryNames: const ['Eletrônica'],
          delta: -5,
          previousQuantity: 20,
          newQuantity: 15,
          type: 'CART_CHECKOUT',
          operatorName: 'Tomas Pereyra',
          createdAt: now.add(const Duration(seconds: 40)),
        ),
      ];

      // Algoritmo de agrupamento
      List<dynamic> groupMovements(List<StockMovementModel> list) {
        final List<dynamic> entries = [];
        int i = 0;
        while (i < list.length) {
          final current = list[i];
          final isUnit = current.type == 'UNIT_ADD' || current.type == 'UNIT_REMOVE';
          if (!isUnit) {
            entries.add(current);
            i++;
            continue;
          }
          final cluster = <StockMovementModel>[current];
          int j = i + 1;
          while (j < list.length) {
            final next = list[j];
            final nextIsUnit = next.type == 'UNIT_ADD' || next.type == 'UNIT_REMOVE';
            if (!nextIsUnit) break;
            if (next.operatorName.trim().toLowerCase() != current.operatorName.trim().toLowerCase()) break;
            if (next.createdAt.difference(cluster.last.createdAt).inSeconds.abs() > 90) break;
            cluster.add(next);
            j++;
          }
          if (cluster.length > 1) {
            entries.add(cluster);
            i = j;
          } else {
            entries.add(current);
            i++;
          }
        }
        return entries;
      }

      final grouped = groupMovements(movements);

      // Deve resultar em 2 entradas:
      // 1: Grupo dos 3 ajustes unitários (mov-1, mov-2, mov-3)
      // 2: Movimentação única de carrinho (mov-4)
      expect(grouped.length, equals(2));
      expect(grouped.first is List, isTrue);
      expect((grouped.first as List).length, equals(3));
      expect(grouped.last is StockMovementModel, isTrue);
      expect((grouped.last as StockMovementModel).id, equals('mov-4'));
    });
  });
}
