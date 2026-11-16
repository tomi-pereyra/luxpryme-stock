import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../datasources/default_categories.dart';
import '../models/cart_item_model.dart';
import '../models/category_model.dart';
import '../models/operator_pin_model.dart';
import '../models/product_model.dart';
import '../models/stock_movement_model.dart';

class InventoryService {
  InventoryService._() {
    _initLocalData();
  }
  static final InventoryService instance = InventoryService._();

  bool _isLocalMode = true;
  bool get isLocalMode => _isLocalMode;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    if (_isLocalMode) return true;
    return _client?.auth.currentSession != null;
  }

  User? get currentUser => _isLocalMode ? null : _client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  // ---------------------------------------------------------------------------
  // ESTADO LOCAL EM MEMÓRIA
  // ---------------------------------------------------------------------------
  late List<CategoryModel> _localCategories;
  late List<ProductModel> _localProducts;
  late List<OperatorPinModel> _localPins;
  late List<StockMovementModel> _localMovements;

  final _categoriesStreamController =
      StreamController<List<CategoryModel>>.broadcast();
  final _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();
  final _pinsStreamController =
      StreamController<List<OperatorPinModel>>.broadcast();
  final _movementsStreamController =
      StreamController<List<StockMovementModel>>.broadcast();

  void _initLocalData() {
    _localCategories = List.from(luxprymeDefaultCategories);
    _localProducts = List.from(luxprymeInitialProducts);

    // Carrega dados locais de produtos se o arquivo local_products.json existir na máquina (ignorado no git)
    try {
      final file = File('local_products.json');
      if (file.existsSync()) {
        final jsonStr = file.readAsStringSync();
        final List list = jsonDecode(jsonStr);
        final catMap = {for (var c in _localCategories) c.id: c.name};
        _localProducts = list.map((item) {
          final map = Map<String, dynamic>.from(item);
          final catIds = (map['category_ids'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final catNames = catIds.map((id) => catMap[id] ?? id).toList();
          return ProductModel.fromMap(map, categoryNames: catNames);
        }).toList();
      }
    } catch (e) {
      debugPrint('Aviso ao carregar produtos locais: $e');
    }
    _localPins = [
      OperatorPinModel(
        id: 'pin-1',
        name: 'Tomas (Supervisor Geral - Acesso Total)',
        pin: '2026',
        masterCategory: 'todas',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: 'pin-2',
        name: 'Roberto (Líder Produção)',
        pin: '1234',
        masterCategory: 'producao',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: 'pin-3',
        name: 'Linha de Montagem SMD',
        pin: '1111',
        masterCategory: 'eletronica',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: 'pin-4',
        name: 'Bancada PTH / Soldagem',
        pin: '2222',
        masterCategory: 'eletronica',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: 'pin-5',
        name: 'Montagem de Luminárias',
        pin: '3333',
        masterCategory: 'producao',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
    _localMovements = [];
    _notifyLocal();
  }

  void _notifyLocal() {
    if (!_categoriesStreamController.isClosed) {
      _categoriesStreamController.add(List.unmodifiable(_localCategories));
    }
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_localProducts));
    }
    if (!_pinsStreamController.isClosed) {
      _pinsStreamController.add(List.unmodifiable(_localPins));
    }
    if (!_movementsStreamController.isClosed) {
      _movementsStreamController.add(List.unmodifiable(_localMovements));
    }
  }

  void setMode({required bool localMode}) {
    _isLocalMode = localMode;
    if (localMode) {
      _notifyLocal();
    }
  }

  // ---------------------------------------------------------------------------
  // AUTENTICAÇÃO E CONTROLE DE ACESSO DO ADMINISTRADOR
  // ---------------------------------------------------------------------------

  static const String adminEmail = 'tomibr20@gmail.com';

  String? get currentUserEmail {
    if (_client != null) {
      return _client!.auth.currentUser?.email;
    }
    return null;
  }

  bool get isAdminUser {
    final email = currentUserEmail?.trim().toLowerCase();
    if (email == adminEmail) return true;
    // Permite em modo local puro (sem conexão Supabase) apenas para testes locais
    if (_isLocalMode && email == null) return true;
    return false;
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (_isLocalMode) return null;

    try {
      final response = await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('Erro de autenticação: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_isLocalMode && _client != null) {
      await _client!.auth.signOut();
    }
  }

  // ---------------------------------------------------------------------------
  // CATEGORIAS
  // ---------------------------------------------------------------------------

  Stream<List<CategoryModel>> streamCategories() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _categoriesStreamController.add(_localCategories));
      return _categoriesStreamController.stream;
    }

    return _client!
        .from(AppConstants.tableCategories)
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((records) => records.map((e) => CategoryModel.fromMap(e)).toList());
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    if (_isLocalMode || _client == null) {
      final newCat = CategoryModel(
        id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        description: description?.trim(),
        createdAt: DateTime.now(),
      );
      _localCategories.add(newCat);
      _notifyLocal();
      return newCat;
    }

    final res = await _client!
        .from(AppConstants.tableCategories)
        .insert({
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        })
        .select()
        .single();

    return CategoryModel.fromMap(res);
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_isLocalMode || _client == null) {
      final hasProducts =
          _localProducts.any((p) => p.categoryIds.contains(categoryId));
      if (hasProducts) {
        throw Exception(
          'Não é possível excluir esta categoria pois existem produtos associados a ela.',
        );
      }
      _localCategories.removeWhere((c) => c.id == categoryId);
      _notifyLocal();
      return;
    }

    final countRes = await _client!
        .from(AppConstants.tableProducts)
        .select('id')
        .contains('category_ids', [categoryId]);

    if (countRes.isNotEmpty) {
      throw Exception(
        'Não é possível excluir esta categoria pois existem ${countRes.length} produto(s) associados a ela.',
      );
    }

    await _client!
        .from(AppConstants.tableCategories)
        .delete()
        .eq('id', categoryId);
  }

  // ---------------------------------------------------------------------------
  // PRODUTOS
  // ---------------------------------------------------------------------------

  bool _isLoadingProducts = false;
  List<ProductModel> _allProducts = [];
  RealtimeChannel? _productsRealtimeChannel;

  Stream<List<ProductModel>> streamProducts() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _productsStreamController.add(_localProducts));
      return _productsStreamController.stream;
    }

    // Se já temos produtos carregados na memória, emite imediatamente
    if (_allProducts.isNotEmpty) {
      Timer.run(() => _productsStreamController.add(List.unmodifiable(_allProducts)));
    }

    // Dispara a carga de todas as páginas no Supabase (superando o limite de 1000)
    fetchProducts();

    // Inscreve no canal realtime para receber alterações incrementais
    _subscribeProductsRealtime();

    return _productsStreamController.stream;
  }

  Future<List<ProductModel>> fetchProducts() async {
    if (_isLocalMode || _client == null) {
      return _localProducts;
    }
    if (_isLoadingProducts) return _allProducts;
    _isLoadingProducts = true;

    try {
      final List<ProductModel> loaded = [];
      int from = 0;
      const int pageSize = 1000;

      while (true) {
        final res = await _client!
            .from(AppConstants.tableProducts)
            .select()
            .order('name', ascending: true)
            .range(from, from + pageSize - 1);

        final items = (res as List)
            .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
            .toList();

        loaded.addAll(items);
        if (items.length < pageSize) break;
        from += pageSize;
      }

      _allProducts = loaded;
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts));
      }
      return _allProducts;
    } catch (e) {
      debugPrint('Erro ao carregar catálogo completo de produtos: $e');
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  void _subscribeProductsRealtime() {
    if (_productsRealtimeChannel != null || _client == null) return;

    _productsRealtimeChannel = _client!
        .channel('public:products_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tableProducts,
          callback: (payload) {
            final record = payload.newRecord;
            final oldRecord = payload.oldRecord;

            if (payload.eventType == PostgresChangeEvent.insert && record.isNotEmpty) {
              final newP = ProductModel.fromMap(record);
              _allProducts.removeWhere((p) => p.id == newP.id);
              _allProducts.insert(0, newP);
              _allProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              if (!_productsStreamController.isClosed) {
                _productsStreamController.add(List.unmodifiable(_allProducts));
              }
            } else if (payload.eventType == PostgresChangeEvent.update && record.isNotEmpty) {
              final updatedP = ProductModel.fromMap(record);
              final idx = _allProducts.indexWhere((p) => p.id == updatedP.id);
              if (idx != -1) {
                _allProducts[idx] = updatedP;
              } else {
                _allProducts.add(updatedP);
              }
              if (!_productsStreamController.isClosed) {
                _productsStreamController.add(List.unmodifiable(_allProducts));
              }
            } else if (payload.eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
              final delId = oldRecord['id']?.toString();
              if (delId != null) {
                _allProducts.removeWhere((p) => p.id == delId);
                if (!_productsStreamController.isClosed) {
                  _productsStreamController.add(List.unmodifiable(_allProducts));
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> createProduct(ProductModel product, {String? pin}) async {
    if (product.quantity < 0) {
      throw Exception('A quantidade inicial não pode ser negativa.');
    }

    String operatorName = 'Administrador';
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (!op.canModify(product)) {
        throw Exception(
          'Acesso negado: O PIN "${op.name}" (${op.masterCategoryLabel}) '
          'não possui autorização para cadastrar produtos nesta categoria mestre.',
        );
      }
      operatorName = op.name;
    }

    final newProduct = product.copyWith(
      id: product.id.isEmpty
          ? 'prod-${DateTime.now().millisecondsSinceEpoch}'
          : product.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final movement = StockMovementModel(
      id: 'mov-${DateTime.now().microsecondsSinceEpoch}',
      productId: newProduct.id,
      productName: newProduct.name,
      productCode: newProduct.code,
      internalCode: newProduct.internalCode,
      manufacturerCode: newProduct.manufacturerCode,
      categoryNames: newProduct.categoryNames ?? [],
      delta: newProduct.quantity,
      previousQuantity: 0,
      newQuantity: newProduct.quantity,
      type: 'PRODUCT_CREATE',
      operatorName: operatorName,
      pinUsed: pin != null && pin.isNotEmpty ? '****' : null,
      createdAt: DateTime.now(),
    );

    if (_isLocalMode || _client == null) {
      _localProducts.insert(0, newProduct);
      if (newProduct.quantity > 0) {
        await _recordMovement(movement);
      }
      _notifyLocal();
      return;
    }

    final payload = newProduct.toMap();
    try {
      await _client!.from(AppConstants.tableProducts).insert(payload);
    } catch (e) {
      // Fallback gracioso caso a coluna subcategories ainda não exista no Supabase
      if (e.toString().contains('subcategories') || e.toString().contains('PGRST204')) {
        payload.remove('subcategories');
        try {
          await _client!.from(AppConstants.tableProducts).insert(payload);
        } catch (e2) {
          if (e2.toString().contains('subcategory') || e2.toString().contains('PGRST204')) {
            payload.remove('subcategory');
            final currentNotes = newProduct.notes ?? '';
            final cleanNotes =
                currentNotes.replaceAll(RegExp(r'\s*\[subcats?:[^\]]*\]'), '').trim();
            final tag = newProduct.subcategories.isNotEmpty
                ? ' [subcats:${newProduct.subcategories.join(";;")}]'
                : '';
            payload['notes'] = cleanNotes.isEmpty
                ? (tag.isEmpty ? null : tag.trim())
                : '$cleanNotes$tag';

            await _client!.from(AppConstants.tableProducts).insert(payload);
          } else {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }

    if (newProduct.quantity > 0) {
      await _recordMovement(movement);
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    if (product.quantity < 0) {
      throw Exception('A quantidade não pode ser negativa.');
    }

    if (_isLocalMode || _client == null) {
      final index = _localProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _localProducts[index] = product.copyWith(updatedAt: DateTime.now());
        _notifyLocal();
      }
      return;
    }

    final payload = product.toMap();
    try {
      await _client!
          .from(AppConstants.tableProducts)
          .update(payload)
          .eq('id', product.id);
    } catch (e) {
      // Fallback gracioso caso a coluna subcategories ainda não exista no Supabase
      if (e.toString().contains('subcategories') || e.toString().contains('PGRST204')) {
        payload.remove('subcategories');
        try {
          await _client!
              .from(AppConstants.tableProducts)
              .update(payload)
              .eq('id', product.id);
        } catch (e2) {
          if (e2.toString().contains('subcategory') || e2.toString().contains('PGRST204')) {
            payload.remove('subcategory');
            final currentNotes = product.notes ?? '';
            final cleanNotes =
                currentNotes.replaceAll(RegExp(r'\s*\[subcats?:[^\]]*\]'), '').trim();
            final tag = product.subcategories.isNotEmpty
                ? ' [subcats:${product.subcategories.join(";;")}]'
                : '';
            payload['notes'] = cleanNotes.isEmpty
                ? (tag.isEmpty ? null : tag.trim())
                : '$cleanNotes$tag';

            await _client!
                .from(AppConstants.tableProducts)
                .update(payload)
                .eq('id', product.id);
          } else {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteProduct(String productId, {String? pin}) async {
    // Procura o produto antes de remover para gravar no histórico
    ProductModel? targetProduct;
    if (_localProducts.any((p) => p.id == productId)) {
      targetProduct = _localProducts.firstWhere((p) => p.id == productId);
    }

    String operatorName = 'Administrador';
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (targetProduct != null && !op.canModify(targetProduct)) {
        throw Exception(
          'Acesso negado: O PIN "${op.name}" (${op.masterCategoryLabel}) '
          'não possui autorização para excluir produtos desta categoria mestre.',
        );
      }
      operatorName = op.name;
    }

    final movement = targetProduct != null
        ? StockMovementModel(
            id: 'mov-${DateTime.now().microsecondsSinceEpoch}',
            productId: targetProduct.id,
            productName: targetProduct.name,
            productCode: targetProduct.code,
            internalCode: targetProduct.internalCode,
            manufacturerCode: targetProduct.manufacturerCode,
            categoryNames: targetProduct.categoryNames ?? [],
            delta: -targetProduct.quantity,
            previousQuantity: targetProduct.quantity,
            newQuantity: 0,
            type: 'PRODUCT_DELETE',
            operatorName: operatorName,
            pinUsed: pin != null && pin.isNotEmpty ? '****' : null,
            createdAt: DateTime.now(),
          )
        : null;

    if (_isLocalMode || _client == null) {
      _localProducts.removeWhere((p) => p.id == productId);
      if (movement != null) {
        await _recordMovement(movement);
      }
      _notifyLocal();
      return;
    }

    await _client!
        .from(AppConstants.tableProducts)
        .delete()
        .eq('id', productId);

    if (movement != null) {
      await _recordMovement(movement);
    }
  }

  // ---------------------------------------------------------------------------
  // AJUSTE UNITÁRIO (+1 E -1) - DIRETO E RÁPIDO COM REGISTRO NO HISTÓRICO
  // ---------------------------------------------------------------------------

  Future<int> quickAdjustUnit({
    required ProductModel product,
    required int delta, // +1 ou -1
    String? pin,
  }) async {
    String operatorName = 'Ajuste Unitário';
    if (pin != null && pin.isNotEmpty) {
      final operatorPin = await validatePin(pin);
      if (operatorPin == null) throw Exception('PIN incorreto ou não autorizado.');
      if (!operatorPin.canModify(product)) {
        throw Exception(
          'Acesso negado: O PIN "${operatorPin.name}" (${operatorPin.masterCategoryLabel}) '
          'não possui autorização para alterar o item "${product.name}".',
        );
      }
      operatorName = operatorPin.name;
    }

    final int newQuantity = product.quantity + delta;
    if (newQuantity < 0) {
      throw Exception(
        'Estoque indisponível: O item "${product.name}" já está com 0 unidades.',
      );
    }

    final movement = StockMovementModel(
      id: 'mov-${DateTime.now().microsecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      productCode: product.code,
      internalCode: product.internalCode,
      manufacturerCode: product.manufacturerCode,
      categoryNames: product.categoryNames ?? [],
      delta: delta,
      previousQuantity: product.quantity,
      newQuantity: newQuantity,
      type: delta > 0 ? 'UNIT_ADD' : 'UNIT_REMOVE',
      operatorName: operatorName,
      pinUsed: pin != null && pin.isNotEmpty ? '****' : null,
      createdAt: DateTime.now(),
    );

    if (_isLocalMode || _client == null) {
      final index = _localProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _localProducts[index] = _localProducts[index].copyWith(
          quantity: newQuantity,
          updatedAt: DateTime.now(),
        );
      }
      await _recordMovement(movement);
      _notifyLocal();
      return newQuantity;
    }

    // Supabase
    await _client!
        .from(AppConstants.tableProducts)
        .update({'quantity': newQuantity})
        .eq('id', product.id);

    await _recordMovement(movement);
    return newQuantity;
  }

  /// Método de ajuste direto com registro no histórico e validação de PIN
  Future<int> adjustStock({
    required String productId,
    required int currentQuantity,
    required int delta,
    required String pin,
  }) async {
    final operatorPin = await validatePin(pin);
    if (operatorPin == null) {
      throw Exception('PIN de 4 dígitos incorreto ou não autorizado.');
    }

    final int newQuantity = currentQuantity + delta;
    if (newQuantity < 0) {
      throw Exception('Estoque não pode ficar negativo.');
    }

    final product = _localProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => ProductModel(
        id: productId,
        name: 'Item',
        categoryIds: [],
        quantity: currentQuantity,
      ),
    );

    return quickAdjustUnit(product: product, delta: delta, pin: pin);
  }

  // ---------------------------------------------------------------------------
  // PROCESSAMENTO DO CARRINHO COM VALIDAÇÃO DE PIN DE 4 DÍGITOS
  // ---------------------------------------------------------------------------

  Future<OperatorPinModel?> validatePin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 4) return null;

    if (_isLocalMode || _client == null) {
      try {
        return _localPins.firstWhere(
          (p) => p.pin == cleanPin && p.isActive,
        );
      } catch (_) {
        return null;
      }
    }

    final res = await _client!
        .from('operator_pins')
        .select()
        .eq('pin', cleanPin)
        .eq('is_active', true)
        .maybeSingle();

    if (res == null) return null;
    return OperatorPinModel.fromMap(res);
  }

  Future<void> checkoutCart({
    required List<CartItemModel> cartItems,
    required String pin,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('O carrinho de separação está vazio.');
    }

    final operatorPin = await validatePin(pin);
    if (operatorPin == null) {
      throw Exception('PIN incorreto ou não cadastrado no sistema.');
    }

    // Validação de Escopo de Categoria Mestre
    if (!operatorPin.isMasterPin) {
      for (var item in cartItems) {
        if (!operatorPin.canModify(item.product)) {
          throw Exception(
            'Acesso negado: O PIN "${operatorPin.name}" (${operatorPin.masterCategoryLabel}) '
            'não possui autorização para movimentar o item "${item.product.name}".',
          );
        }
      }
    }

    final now = DateTime.now();

    for (var item in cartItems) {
      final currentStock = item.product.quantity;
      final delta = item.delta;
      final newStock = currentStock + delta;

      if (newStock < 0) {
        throw Exception(
          'Saldo insuficiente para "${item.product.name}". Estoque atual: $currentStock un, solicitados: ${item.quantity} un.',
        );
      }

      final movement = StockMovementModel(
        id: 'mov-${now.microsecondsSinceEpoch}-${item.product.id}',
        productId: item.product.id,
        productName: item.product.name,
        productCode: item.product.code,
        internalCode: item.product.internalCode,
        manufacturerCode: item.product.manufacturerCode,
        categoryNames: item.product.categoryNames ?? [],
        delta: delta,
        previousQuantity: currentStock,
        newQuantity: newStock,
        type: item.isWithdrawal ? 'CART_WITHDRAWAL' : 'CART_DEPOSIT',
        operatorName: operatorPin.name,
        pinUsed: '****',
        createdAt: now,
      );

      if (_isLocalMode || _client == null) {
        final index = _localProducts.indexWhere((p) => p.id == item.product.id);
        if (index != -1) {
          _localProducts[index] = _localProducts[index].copyWith(
            quantity: newStock,
            updatedAt: now,
          );
        }
        await _recordMovement(movement);
      } else {
        await _client!
            .from(AppConstants.tableProducts)
            .update({'quantity': newStock})
            .eq('id', item.product.id);

        await _recordMovement(movement);
      }
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
    }
  }

  // ---------------------------------------------------------------------------
  // GESTÃO DE PINS DE OPERADORES (ADMIN WINDOWS)
  // ---------------------------------------------------------------------------

  Stream<List<OperatorPinModel>> streamOperatorPins() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _pinsStreamController.add(_localPins));
      return _pinsStreamController.stream;
    }

    return _client!
        .from('operator_pins')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((records) => records.map((e) => OperatorPinModel.fromMap(e)).toList());
  }

  Future<void> createOperatorPin({
    required String name,
    required String pin,
    String masterCategory = 'eletronica',
  }) async {
    if (pin.trim().length != 4 || int.tryParse(pin.trim()) == null) {
      throw Exception('O PIN deve conter exatamente 4 dígitos numéricos.');
    }

    if (_isLocalMode || _client == null) {
      if (_localPins.any((p) => p.pin == pin.trim())) {
        throw Exception('Este PIN já está cadastrado para outro operador.');
      }
      final newPin = OperatorPinModel(
        id: 'pin-${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        pin: pin.trim(),
        masterCategory: masterCategory.toLowerCase(),
        isActive: true,
        createdAt: DateTime.now(),
      );
      _localPins.add(newPin);
      _notifyLocal();
      return;
    }

    await _client!.from('operator_pins').insert({
      'name': name.trim(),
      'pin': pin.trim(),
      'master_category': masterCategory.toLowerCase(),
      'is_active': true,
    });
  }

  Future<void> moveProductMasterCategories({
    required String productId,
    required List<String> masterCategories,
  }) async {
    if (_isLocalMode || _client == null) {
      final index = _localProducts.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _localProducts[index] = _localProducts[index].copyWith(
          masterCategories: masterCategories,
          updatedAt: DateTime.now(),
        );
        _notifyLocal();
      }
      return;
    }

    await _client!
        .from(AppConstants.tableProducts)
        .update({'master_categories': masterCategories})
        .eq('id', productId);
  }

  Future<void> deleteOperatorPin(String id) async {
    if (_isLocalMode || _client == null) {
      _localPins.removeWhere((p) => p.id == id);
      _notifyLocal();
      return;
    }

    await _client!.from('operator_pins').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // HISTÓRICO DE MOVIMENTAÇÕES (GRAVAÇÃO SEGURA & SINCRONIZAÇÃO HÍBRIDA)
  // ---------------------------------------------------------------------------

  Future<void> _recordMovement(StockMovementModel movement) async {
    // 1. Sempre atualiza a memória local imediatamente (resposta instantânea na UI)
    _localMovements.removeWhere((m) => m.id.isNotEmpty && m.id == movement.id);
    _localMovements.insert(0, movement);
    if (!_movementsStreamController.isClosed) {
      _movementsStreamController.add(List.unmodifiable(_localMovements));
    }

    // 2. Se conectado ao Supabase, grava no banco com payload seguro
    if (!_isLocalMode && _client != null) {
      try {
        final payload = movement.toMap(forDatabaseInsert: true);
        final res = await _client!
            .from('stock_movements')
            .insert(payload)
            .select()
            .maybeSingle();

        if (res != null) {
          final serverMovement = StockMovementModel.fromMap(res);
          final idx = _localMovements.indexOf(movement);
          if (idx != -1) {
            _localMovements[idx] = serverMovement;
          } else {
            _localMovements.insert(0, serverMovement);
          }
          if (!_movementsStreamController.isClosed) {
            _movementsStreamController.add(List.unmodifiable(_localMovements));
          }
        }
      } catch (e) {
        debugPrint('Aviso: falha ao gravar stock_movements no Supabase: $e');
        // Fallback defensivo: se falhar com product_id (por FK ou UUID não existente), tenta sem product_id
        try {
          final fallbackPayload = movement.toMap(forDatabaseInsert: true);
          fallbackPayload['product_id'] = null;
          final res = await _client!
              .from('stock_movements')
              .insert(fallbackPayload)
              .select()
              .maybeSingle();
          if (res != null) {
            final serverMovement = StockMovementModel.fromMap(res);
            final idx = _localMovements.indexOf(movement);
            if (idx != -1) {
              _localMovements[idx] = serverMovement;
              if (!_movementsStreamController.isClosed) {
                _movementsStreamController.add(List.unmodifiable(_localMovements));
              }
            }
          }
        } catch (e2) {
          debugPrint('Falha no fallback de gravação de stock_movements: $e2');
        }
      }
    }
  }

  Future<List<StockMovementModel>> fetchMovements() async {
    if (_isLocalMode || _client == null) {
      return List.unmodifiable(_localMovements);
    }

    try {
      final records = await _client!
          .from('stock_movements')
          .select()
          .order('created_at', ascending: false);

      final list = (records as List)
          .map((e) => StockMovementModel.fromMap(e as Map<String, dynamic>))
          .toList();

      // Mescla com itens locais da sessão atual caso ainda não tenham sido lidos
      final serverIds = list.map((m) => m.id).toSet();
      for (final local in _localMovements) {
        if (!serverIds.contains(local.id)) {
          list.insert(0, local);
        }
      }

      _localMovements = list;
      if (!_movementsStreamController.isClosed) {
        _movementsStreamController.add(List.unmodifiable(_localMovements));
      }
      return list;
    } catch (e) {
      debugPrint('Aviso: falha ao buscar movimentações via REST: $e');
      return List.unmodifiable(_localMovements);
    }
  }

  Stream<List<StockMovementModel>> streamMovements() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _movementsStreamController.add(List.unmodifiable(_localMovements)));
      return _movementsStreamController.stream;
    }

    // Busca via REST imediatamente para carregar dados mesmo se o realtime não estiver ativo
    fetchMovements();

    // Inicia listener realtime para sincronização contínua com outros dispositivos
    try {
      _client!
          .from('stock_movements')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen(
            (records) {
              final list = records.map((e) => StockMovementModel.fromMap(e)).toList();
              final serverIds = list.map((m) => m.id).toSet();
              for (final local in _localMovements) {
                if (!serverIds.contains(local.id)) {
                  list.insert(0, local);
                }
              }
              _localMovements = list;
              if (!_movementsStreamController.isClosed) {
                _movementsStreamController.add(List.unmodifiable(_localMovements));
              }
            },
            onError: (err) {
              debugPrint('Aviso no stream realtime de stock_movements: $err (fallback ativo)');
            },
          );
    } catch (e) {
      debugPrint('Erro ao iniciar realtime de stock_movements: $e');
    }

    return _movementsStreamController.stream;
  }
}
