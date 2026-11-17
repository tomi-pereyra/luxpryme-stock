import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../datasources/default_categories.dart';
import '../models/cart_item_model.dart';
import '../models/category_model.dart';
import '../models/master_category_model.dart';
import '../models/operator_pin_model.dart';
import '../models/product_model.dart';
import '../models/stock_conflict_model.dart';
import '../models/stock_movement_model.dart';
import 'local_cache_service.dart';

class InventoryService {
  InventoryService._() {
    _initLocalData();
    // Inicia carregamento do cache em disco em segundo plano
    initLocalCache();
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
  // ESTADO LOCAL EM MEMÓRIA E CATEGORIAS MESTRES PADRÃO
  // ---------------------------------------------------------------------------
  static const List<MasterCategoryModel> defaultMasterCategories = [
    MasterCategoryModel(
      id: 'eletronica',
      name: 'Eletrônica',
      description: 'Componentes eletrônicos, semicondutores, PCBs e insumos de eletrônica',
      colorHex: '#2563EB',
      iconName: 'memory',
      isSystemDefault: true,
    ),
    MasterCategoryModel(
      id: 'producao',
      name: 'Produção',
      description: 'Componentes e insumos para montagem do produto final',
      colorHex: '#059669',
      iconName: 'precision_manufacturing',
      isSystemDefault: true,
    ),
    MasterCategoryModel(
      id: 'outros',
      name: 'Outros',
      description: 'Insumos gerais, manutenção predial e civil',
      colorHex: '#64748B',
      iconName: 'inventory_2',
      isSystemDefault: true,
    ),
  ];

  late List<CategoryModel> _localCategories;
  late List<ProductModel> _localProducts;
  late List<OperatorPinModel> _localPins;
  late List<StockMovementModel> _localMovements;
  late List<MasterCategoryModel> _masterCategories;
  List<StockConflictModel> _conflicts = [];

  final _categoriesStreamController =
      StreamController<List<CategoryModel>>.broadcast();
  final _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();
  final _pinsStreamController =
      StreamController<List<OperatorPinModel>>.broadcast();
  final _movementsStreamController =
      StreamController<List<StockMovementModel>>.broadcast();
  final _masterCategoriesStreamController =
      StreamController<List<MasterCategoryModel>>.broadcast();
  final _conflictsStreamController =
      StreamController<List<StockConflictModel>>.broadcast();

  List<MasterCategoryModel> get masterCategories =>
      List.unmodifiable(_masterCategories);

  List<StockConflictModel> get activeConflicts =>
      List.unmodifiable(_conflicts);

  Stream<List<StockConflictModel>> streamStockConflicts() {
    Timer.run(() {
      if (!_conflictsStreamController.isClosed) {
        _conflictsStreamController.add(List.unmodifiable(_conflicts));
      }
    });
    return _conflictsStreamController.stream;
  }

  bool _isCacheLoaded = false;
  bool get isCacheLoaded => _isCacheLoaded;

  Future<void> initLocalCache() async {
    try {
      final cachedProducts = await LocalCacheService.instance.loadProducts();
      if (cachedProducts != null && cachedProducts.isNotEmpty) {
        _allProducts = cachedProducts;
        _localProducts = cachedProducts;
        if (!_productsStreamController.isClosed) {
          _productsStreamController.add(List.unmodifiable(_allProducts));
        }
      }

      final cachedCategories = await LocalCacheService.instance.loadCategories();
      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        _localCategories = cachedCategories;
        if (!_categoriesStreamController.isClosed) {
          _categoriesStreamController.add(List.unmodifiable(_localCategories));
        }
      }

      final cachedMasterCats = await LocalCacheService.instance.loadMasterCategories();
      if (cachedMasterCats != null && cachedMasterCats.isNotEmpty) {
        _masterCategories = cachedMasterCats;
        if (!_masterCategoriesStreamController.isClosed) {
          _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
        }
      }

      final cachedPins = await LocalCacheService.instance.loadPins();
      if (cachedPins != null && cachedPins.isNotEmpty) {
        _localPins = cachedPins;
        if (!_pinsStreamController.isClosed) {
          _pinsStreamController.add(List.unmodifiable(_localPins));
        }
      }

      final cachedMovements = await LocalCacheService.instance.loadMovements();
      if (cachedMovements != null && cachedMovements.isNotEmpty) {
        _localMovements = cachedMovements;
        if (!_movementsStreamController.isClosed) {
          _movementsStreamController.add(List.unmodifiable(_localMovements));
        }
      }

      final cachedConflicts = await LocalCacheService.instance.loadConflicts();
      if (cachedConflicts.isNotEmpty) {
        _conflicts = cachedConflicts;
        if (!_conflictsStreamController.isClosed) {
          _conflictsStreamController.add(List.unmodifiable(_conflicts));
        }
      }

      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('Aviso ao inicializar cache local persistente: $e');
    }
  }

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

    _masterCategories = List.from(defaultMasterCategories);
    try {
      final file = File('local_master_categories.json');
      if (file.existsSync()) {
        final jsonStr = file.readAsStringSync();
        final List list = jsonDecode(jsonStr);
        final custom = list
            .map((e) => MasterCategoryModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        for (final c in custom) {
          if (!_masterCategories.any((m) => m.id.toLowerCase() == c.id.toLowerCase())) {
            _masterCategories.add(c);
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso ao carregar categorias mestres locais: $e');
    }

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
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
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
  // CATEGORIAS MESTRES INDUSTRIAIS (ELETRÔNICA, PRODUÇÃO, PREPARAÇÃO, ETC.)
  // ---------------------------------------------------------------------------

  RealtimeChannel? _masterCategoriesRealtimeChannel;

  Stream<List<MasterCategoryModel>> streamMasterCategories() {
    if (_isLocalMode || _client == null) {
      scheduleMicrotask(() {
        if (!_masterCategoriesStreamController.isClosed) {
          _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
        }
      });
      return _masterCategoriesStreamController.stream;
    }

    scheduleMicrotask(() {
      if (!_masterCategoriesStreamController.isClosed) {
        _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
      }
    });
    fetchMasterCategories();
    _subscribeMasterCategoriesRealtime();
    return _masterCategoriesStreamController.stream;
  }

  Future<List<MasterCategoryModel>> fetchMasterCategories() async {
    if (_isLocalMode || _client == null) {
      return List.unmodifiable(_masterCategories);
    }

    try {
      final res = await _client!
          .from(AppConstants.tableMasterCategories)
          .select()
          .order('name', ascending: true);

      final items = (res as List)
          .map((e) => MasterCategoryModel.fromMap(e as Map<String, dynamic>))
          .toList();

      if (items.isNotEmpty) {
        final merged = List<MasterCategoryModel>.from(defaultMasterCategories);
        for (final item in items) {
          final idx = merged.indexWhere((m) => m.id.toLowerCase() == item.id.toLowerCase());
          if (idx != -1) {
            merged[idx] = item;
          } else {
            merged.add(item);
          }
        }
        _masterCategories = merged;
      }
      if (!_masterCategoriesStreamController.isClosed) {
        _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
      }
      _saveMasterCategoriesLocal();
      return _masterCategories;
    } catch (e) {
      debugPrint('Aviso ao carregar master_categories do Supabase: $e');
      return _masterCategories;
    }
  }

  void _subscribeMasterCategoriesRealtime() {
    if (_masterCategoriesRealtimeChannel != null || _client == null) return;

    _masterCategoriesRealtimeChannel = _client!
        .channel('public:master_categories_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tableMasterCategories,
          callback: (payload) {
            fetchMasterCategories();
          },
        )
        .subscribe();
  }

  String generateMasterCategorySlug(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàãâä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìîï]'), 'i');
    s = s.replaceAll(RegExp(r'[óòõôö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'cat_${DateTime.now().millisecondsSinceEpoch}' : s;
  }

  String getMasterCategoryName(String id) {
    final found = _masterCategories.firstWhere(
      (m) => m.id.toLowerCase() == id.toLowerCase(),
      orElse: () => MasterCategoryModel(id: id, name: id),
    );
    return found.name;
  }

  Future<MasterCategoryModel> createMasterCategory({
    required String name,
    String? description,
    String? colorHex,
    String? iconName,
    required String masterPin,
  }) async {
    final operator = await validatePin(masterPin);
    if (operator == null) {
      throw Exception('PIN incorreto ou não cadastrado no sistema.');
    }
    if (!operator.isMasterPin) {
      throw Exception(
        'Acesso negado: O PIN informado pertence a "${operator.name}". '
        'Apenas operadores com PIN Mestre (ex: Supervisor Geral) têm autorização para adicionar setores.',
      );
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Informe o nome do setor.');
    }

    final id = generateMasterCategorySlug(cleanName);
    if (_masterCategories.any((mc) => mc.id.toLowerCase() == id)) {
      throw Exception('Já existe um setor com o identificador "$id".');
    }

    final newMaster = MasterCategoryModel(
      id: id,
      name: cleanName,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      colorHex: colorHex,
      iconName: iconName,
      createdAt: DateTime.now(),
      isSystemDefault: false,
    );

    if (!_isLocalMode && _client != null) {
      try {
        await _client!.from(AppConstants.tableMasterCategories).insert({
          'id': id,
          'name': cleanName,
          if (newMaster.description != null) 'description': newMaster.description,
          if (newMaster.colorHex != null) 'color': newMaster.colorHex,
          if (newMaster.iconName != null) 'icon': newMaster.iconName,
        });
      } catch (e) {
        debugPrint('Aviso ao inserir master_category no Supabase: $e');
      }
    }

    _masterCategories.add(newMaster);
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }
    return newMaster;
  }

  Future<MasterCategoryModel> updateMasterCategory({
    required String id,
    required String name,
    String? description,
    String? colorHex,
    String? iconName,
    required String masterPin,
  }) async {
    final operator = await validatePin(masterPin);
    if (operator == null) {
      throw Exception('PIN incorreto ou não cadastrado no sistema.');
    }
    if (!operator.isMasterPin) {
      throw Exception(
        'Acesso negado: O PIN informado pertence a "${operator.name}". '
        'Apenas operadores com PIN Mestre têm autorização para modificar setores.',
      );
    }

    final index = _masterCategories.indexWhere((mc) => mc.id.toLowerCase() == id.toLowerCase());
    if (index == -1) {
      throw Exception('Setor "$id" não encontrado.');
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('O nome do setor não pode ser vazio.');
    }

    final existing = _masterCategories[index];
    final updated = existing.copyWith(
      name: cleanName,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      colorHex: colorHex ?? existing.colorHex,
      iconName: iconName ?? existing.iconName,
    );

    if (!_isLocalMode && _client != null) {
      try {
        await _client!.from(AppConstants.tableMasterCategories).update({
          'name': updated.name,
          'description': updated.description,
          'color': updated.colorHex,
          'icon': updated.iconName,
        }).eq('id', id);
      } catch (e) {
        debugPrint('Aviso ao atualizar master_category no Supabase: $e');
      }
    }

    _masterCategories[index] = updated;
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }
    return updated;
  }

  Future<void> deleteMasterCategory({
    required String id,
    required String masterPin,
  }) async {
    final operator = await validatePin(masterPin);
    if (operator == null) {
      throw Exception('PIN incorreto ou não cadastrado no sistema.');
    }
    if (!operator.isMasterPin) {
      throw Exception(
        'Acesso negado: O PIN informado pertence a "${operator.name}". '
        'Apenas operadores com PIN Mestre têm autorização para excluir setores.',
      );
    }

    final lowerId = id.toLowerCase();
    if (lowerId == 'outros') {
      throw Exception('O setor "Outros" é padrão do sistema e não pode ser excluído.');
    }

    // Desvincula dos produtos que tinham essa categoria mestre, movendo para 'outros' se ficarem sem nenhuma
    for (int i = 0; i < _allProducts.length; i++) {
      final p = _allProducts[i];
      if (p.masterCategories.contains(lowerId)) {
        final newCats = List<String>.from(p.masterCategories)..remove(lowerId);
        if (newCats.isEmpty) newCats.add('outros');
        _allProducts[i] = p.copyWith(masterCategories: newCats);
        if (!_isLocalMode && _client != null) {
          _client!
              .from(AppConstants.tableProducts)
              .update({'master_categories': newCats})
              .eq('id', p.id)
              .then((_) {}, onError: (e) => debugPrint('Erro ao desvincular categoria de produto: $e'));
        }
      }
    }
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts));
    }

    // Se houver algum PIN vinculado exclusivamente a essa categoria, migra para 'outros'
    for (int i = 0; i < _localPins.length; i++) {
      if (_localPins[i].masterCategory.toLowerCase() == lowerId) {
        _localPins[i] = _localPins[i].copyWith(masterCategory: 'outros');
      }
    }
    if (!_isLocalMode && _client != null) {
      try {
        await _client!
            .from('operator_pins')
            .update({'master_category': 'outros'})
            .eq('master_category', lowerId);
      } catch (_) {}
    }

    if (!_isLocalMode && _client != null) {
      try {
        await _client!.from(AppConstants.tableMasterCategories).delete().eq('id', id);
      } catch (e) {
        debugPrint('Aviso ao remover master_category do Supabase: $e');
      }
    }

    _masterCategories.removeWhere((mc) => mc.id.toLowerCase() == lowerId);
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }
  }

  void _saveMasterCategoriesLocal() {
    try {
      final file = File('local_master_categories.json');
      final list = _masterCategories.map((mc) => mc.toMap()).toList();
      file.writeAsStringSync(jsonEncode(list));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // PRODUTOS
  // ---------------------------------------------------------------------------

  bool _isLoadingProducts = false;
  List<ProductModel> _allProducts = [];
  List<ProductModel> get currentProducts =>
      List.unmodifiable(_isLocalMode || _client == null ? _localProducts : _allProducts);
  RealtimeChannel? _productsRealtimeChannel;

  Stream<List<ProductModel>> streamProducts() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _productsStreamController.add(_localProducts));
      return _productsStreamController.stream;
    }

    // Se já temos produtos carregados na memória (do cache ou pré-carregados), emite imediatamente (0ms)
    if (_allProducts.isNotEmpty) {
      Timer.run(() => _productsStreamController.add(List.unmodifiable(_allProducts)));
    }

    // Sincroniza em segundo plano sem congelar a interface
    fetchProducts();

    // Inscreve no canal realtime para receber alterações incrementais
    _subscribeProductsRealtime();

    return _productsStreamController.stream;
  }

  bool _isFlushingQueue = false;

  Future<void> _flushPendingSyncQueue() async {
    if (_isFlushingQueue || _isLocalMode || _client == null) return;
    _isFlushingQueue = true;
    try {
      final queue = await LocalCacheService.instance.loadPendingSyncActions();
      if (queue.isEmpty) return;

      debugPrint('Sincronizando ${queue.length} ações pendentes da fila offline...');
      for (final action in queue) {
        final type = action['action_type']?.toString();
        try {
          switch (type) {
            case 'quick_adjust':
              final productId = action['product_id']?.toString();
              final newQty = action['new_quantity'] as int?;
              if (productId != null && newQty != null) {
                await _client!
                    .from(AppConstants.tableProducts)
                    .update({'quantity': newQty})
                    .eq('id', productId);
              }
              if (action['movement'] != null) {
                final mov = StockMovementModel.fromMap(Map<String, dynamic>.from(action['movement']));
                await _recordMovement(mov);
              }
              break;

            case 'checkout_cart':
              final List items = action['items'] as List? ?? [];
              for (final it in items) {
                final itMap = Map<String, dynamic>.from(it);
                final pId = itMap['product_id']?.toString();
                final nQty = itMap['new_quantity'] as int?;
                if (pId != null && nQty != null) {
                  await _client!
                      .from(AppConstants.tableProducts)
                      .update({'quantity': nQty})
                      .eq('id', pId);
                }
              }
              final List movements = action['movements'] as List? ?? [];
              for (final m in movements) {
                final mov = StockMovementModel.fromMap(Map<String, dynamic>.from(m));
                await _recordMovement(mov);
              }
              break;

            case 'create_product':
              final productMap = Map<String, dynamic>.from(action['product']);
              final prod = ProductModel.fromMap(productMap);
              await _client!.from(AppConstants.tableProducts).insert(prod.toMap());
              break;

            case 'update_product':
              final productMap = Map<String, dynamic>.from(action['product']);
              final prod = ProductModel.fromMap(productMap);
              await _client!
                  .from(AppConstants.tableProducts)
                  .update(prod.toMap())
                  .eq('id', prod.id);
              break;

            case 'delete_product':
              final pId = action['product_id']?.toString();
              if (pId != null) {
                await _client!.from(AppConstants.tableProducts).delete().eq('id', pId);
              }
              break;

            case 'bulk_add_master_cat':
            case 'bulk_remove_master_cat':
            case 'move_master_cat':
              final pId = action['product_id']?.toString();
              final mCats = (action['master_categories'] as List?)?.map((e) => e.toString()).toList();
              if (pId != null && mCats != null) {
                await _client!
                    .from(AppConstants.tableProducts)
                    .update({'master_categories': mCats})
                    .eq('id', pId);
              }
              break;

            case 'resolve_conflict':
              final pId = action['product_id']?.toString();
              final qty = action['quantity'] as int?;
              if (pId != null && qty != null) {
                await _client!
                    .from(AppConstants.tableProducts)
                    .update({'quantity': qty})
                    .eq('id', pId);
              }
              if (action['movement'] != null) {
                final mov = StockMovementModel.fromMap(Map<String, dynamic>.from(action['movement']));
                await _recordMovement(mov);
              }
              break;
          }
        } catch (itemErr) {
          debugPrint('Aviso ao sincronizar item da fila offline ($type): $itemErr');
        }
      }
      await LocalCacheService.instance.clearPendingSyncActions();
      debugPrint('Fila offline descarregada com sucesso.');
    } catch (e) {
      debugPrint('Aviso ao descarregar fila offline: $e');
    } finally {
      _isFlushingQueue = false;
    }
  }

  Future<List<ProductModel>> fetchProducts({bool forceRefresh = false}) async {
    if (_isLocalMode || _client == null) {
      return _allProducts.isNotEmpty ? _allProducts : _localProducts;
    }

    // Se já temos produtos no catálogo local e não é atualização forçada, retorna imediatamente
    // e executa a sincronização em segundo plano para não congelar o app
    if (_allProducts.isNotEmpty && !forceRefresh) {
      scheduleMicrotask(() async {
        try {
          await _executeProductsFetch();
        } catch (e) {
          debugPrint('Sincronização em segundo plano com Supabase: $e');
        }
      });
      return _allProducts;
    }

    return _executeProductsFetch();
  }

  Future<List<ProductModel>> _executeProductsFetch() async {
    if (_isLoadingProducts) return _allProducts;
    _isLoadingProducts = true;

    try {
      // 1. Descarrega qualquer alteração offline pendente
      await _flushPendingSyncQueue();

      // 2. Baixa catálogo completo do Supabase superando o limite de 1000
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
      _localProducts = loaded;

      // 3. Salva no cache local em disco (para inicializações instantâneas)
      await LocalCacheService.instance.saveProducts(_allProducts);

      // 4. Detecção de Conflitos: Verifica produtos com saldo negativo
      _detectAndHandleStockConflicts();

      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts));
      }
      return _allProducts;
    } catch (e) {
      debugPrint('Aviso ao baixar catálogo do Supabase (mantendo cache local): $e');
      // Se falhou por falta de internet, carrega do cache local se ainda não o tiver
      if (_allProducts.isEmpty) {
        final cached = await LocalCacheService.instance.loadProducts();
        if (cached != null && cached.isNotEmpty) {
          _allProducts = cached;
          _localProducts = cached;
          _detectAndHandleStockConflicts();
          if (!_productsStreamController.isClosed) {
            _productsStreamController.add(List.unmodifiable(_allProducts));
          }
        }
      }
      return _allProducts;
    } finally {
      _isLoadingProducts = false;
    }
  }

  void _detectAndHandleStockConflicts() {
    final List<StockConflictModel> detected = [];
    for (final p in _allProducts) {
      if (p.quantity < 0) {
        detected.add(StockConflictModel(
          id: 'conflict-${p.id}',
          productId: p.id,
          productName: p.name,
          productCode: p.code,
          internalCode: p.internalCode,
          currentQuantity: p.quantity,
          deficitAmount: -p.quantity,
          reason: 'Saldo negativo detectado após saídas simultâneas registradas em múltiplos dispositivos.',
          detectedAt: DateTime.now(),
        ));
      }
    }
    _conflicts = detected;
    LocalCacheService.instance.saveConflicts(_conflicts);
    if (!_conflictsStreamController.isClosed) {
      _conflictsStreamController.add(List.unmodifiable(_conflicts));
    }
  }

  // ---------------------------------------------------------------------------
  // RESOLUÇÃO DE CONFLITOS DE ESTOQUE (SALDO NEGATIVO)
  // ---------------------------------------------------------------------------

  Future<void> resolveConflictSetStock({
    required String conflictId,
    required String productId,
    required int newQuantity,
    required String masterPin,
    String? note,
  }) async {
    final operator = await validatePin(masterPin);
    if (operator == null) {
      throw Exception('PIN incorreto ou não cadastrado.');
    }
    if (!operator.isMasterPin) {
      throw Exception('Apenas operadores com PIN Mestre têm autorização para resolver conflitos de estoque.');
    }
    if (newQuantity < 0) {
      throw Exception('A nova quantidade informada não pode ser negativa.');
    }

    final pIdx = _allProducts.indexWhere((p) => p.id == productId);
    ProductModel? product;
    int oldQty = 0;
    if (pIdx != -1) {
      product = _allProducts[pIdx];
      oldQty = product.quantity;
      _allProducts[pIdx] = product.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts));
      }
      await LocalCacheService.instance.saveProducts(_allProducts);
    }

    final movement = StockMovementModel(
      id: 'mov-resolve-${DateTime.now().microsecondsSinceEpoch}',
      productId: productId,
      productName: product?.name ?? 'Item Conflito',
      productCode: product?.code,
      internalCode: product?.internalCode,
      manufacturerCode: product?.manufacturerCode,
      categoryNames: product?.categoryNames ?? [],
      delta: newQuantity - oldQty,
      previousQuantity: oldQty,
      newQuantity: newQuantity,
      type: 'CONFLICT_RESOLUTION_SET',
      operatorName: operator.name,
      pinUsed: '****',
      notes: note ?? 'Resolução de Conflito: Saldo real ajustado para $newQuantity un.',
      createdAt: DateTime.now(),
    );

    await _recordMovement(movement);

    if (!_isLocalMode && _client != null) {
      try {
        await _client!
            .from(AppConstants.tableProducts)
            .update({'quantity': newQuantity})
            .eq('id', productId);
      } catch (e) {
        await LocalCacheService.instance.queueSyncAction({
          'action_type': 'resolve_conflict',
          'product_id': productId,
          'quantity': newQuantity,
          'movement': movement.toMap(),
        });
      }
    }

    _conflicts.removeWhere((c) => c.id == conflictId || c.productId == productId);
    await LocalCacheService.instance.saveConflicts(_conflicts);
    if (!_conflictsStreamController.isClosed) {
      _conflictsStreamController.add(List.unmodifiable(_conflicts));
    }
  }

  Future<void> resolveConflictRevertDeficit({
    required String conflictId,
    required String productId,
    required int deficitAmount,
    required String masterPin,
  }) async {
    return resolveConflictSetStock(
      conflictId: conflictId,
      productId: productId,
      newQuantity: 0,
      masterPin: masterPin,
      note: 'Resolução de Conflito: Estorno do déficit de $deficitAmount un (saldo redefinido para 0 un).',
    );
  }

  Future<void> dismissConflict(String conflictId) async {
    _conflicts.removeWhere((c) => c.id == conflictId);
    await LocalCacheService.instance.saveConflicts(_conflicts);
    if (!_conflictsStreamController.isClosed) {
      _conflictsStreamController.add(List.unmodifiable(_conflicts));
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
          'não possui autorização para cadastrar produtos neste setor.',
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

    _allProducts.insert(0, newProduct);
    _localProducts.insert(0, newProduct);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts));
    }
    await LocalCacheService.instance.saveProducts(_allProducts);

    if (_isLocalMode || _client == null) {
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

            try {
              await _client!.from(AppConstants.tableProducts).insert(payload);
            } catch (e3) {
              debugPrint('Aviso: offline ao criar produto, enfileirando: $e3');
              await LocalCacheService.instance.queueSyncAction({
                'action_type': 'create_product',
                'product': newProduct.toMap(),
              });
            }
          } else {
            debugPrint('Aviso: offline ao criar produto, enfileirando: $e2');
            await LocalCacheService.instance.queueSyncAction({
              'action_type': 'create_product',
              'product': newProduct.toMap(),
            });
          }
        }
      } else {
        debugPrint('Aviso: offline ao criar produto, enfileirando: $e');
        await LocalCacheService.instance.queueSyncAction({
          'action_type': 'create_product',
          'product': newProduct.toMap(),
        });
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

    final updated = product.copyWith(updatedAt: DateTime.now());
    final index = _localProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _localProducts[index] = updated;
    }
    final allIdx = _allProducts.indexWhere((p) => p.id == product.id);
    if (allIdx != -1) {
      _allProducts[allIdx] = updated;
    }
    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    final payload = updated.toMap();
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
            final currentNotes = updated.notes ?? '';
            final cleanNotes =
                currentNotes.replaceAll(RegExp(r'\s*\[subcats?:[^\]]*\]'), '').trim();
            final tag = updated.subcategories.isNotEmpty
                ? ' [subcats:${updated.subcategories.join(";;")}]'
                : '';
            payload['notes'] = cleanNotes.isEmpty
                ? (tag.isEmpty ? null : tag.trim())
                : '$cleanNotes$tag';

            try {
              await _client!
                  .from(AppConstants.tableProducts)
                  .update(payload)
                  .eq('id', product.id);
            } catch (e3) {
              await LocalCacheService.instance.queueSyncAction({
                'action_type': 'update_product',
                'product': updated.toMap(),
              });
            }
          } else {
            await LocalCacheService.instance.queueSyncAction({
              'action_type': 'update_product',
              'product': updated.toMap(),
            });
          }
        }
      } else {
        await LocalCacheService.instance.queueSyncAction({
          'action_type': 'update_product',
          'product': updated.toMap(),
        });
      }
    }
  }

  Future<void> deleteProduct(String productId, {String? pin}) async {
    // Procura o produto antes de remover para gravar no histórico
    ProductModel? targetProduct;
    if (_localProducts.any((p) => p.id == productId)) {
      targetProduct = _localProducts.firstWhere((p) => p.id == productId);
    } else if (_allProducts.any((p) => p.id == productId)) {
      targetProduct = _allProducts.firstWhere((p) => p.id == productId);
    }

    String operatorName = 'Administrador';
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (targetProduct != null && !op.canModify(targetProduct)) {
        throw Exception(
          'Acesso negado: O PIN "${op.name}" (${op.masterCategoryLabel}) '
          'não possui autorização para excluir produtos deste setor.',
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

    _localProducts.removeWhere((p) => p.id == productId);
    _allProducts.removeWhere((p) => p.id == productId);
    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (movement != null) {
      await _recordMovement(movement);
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    try {
      await _client!
          .from(AppConstants.tableProducts)
          .delete()
          .eq('id', productId);
    } catch (e) {
      debugPrint('Aviso: offline ao deletar produto, enfileirando: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'delete_product',
        'product_id': productId,
      });
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

    // 1. Sempre atualiza em memória imediatamente
    final localIdx = _localProducts.indexWhere((p) => p.id == product.id);
    if (localIdx != -1) {
      _localProducts[localIdx] = _localProducts[localIdx].copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
    }
    final allIdx = _allProducts.indexWhere((p) => p.id == product.id);
    if (allIdx != -1) {
      _allProducts[allIdx] = _allProducts[allIdx].copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
    }

    await _recordMovement(movement);
    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);

    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return newQuantity;
    }

    // Supabase com fallback offline resiliente
    try {
      await _client!
          .from(AppConstants.tableProducts)
          .update({'quantity': newQuantity})
          .eq('id', product.id);
    } catch (e) {
      debugPrint('Aviso: falha de rede no ajuste unitário, enfileirando ação offline: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'quick_adjust',
        'product_id': product.id,
        'new_quantity': newQuantity,
        'movement': movement.toMap(),
      });
    }

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
    String? notes,
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
        notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
        createdAt: now,
      );

      // Atualiza memória local imediatamente
      final idx = _localProducts.indexWhere((p) => p.id == item.product.id);
      if (idx != -1) {
        _localProducts[idx] = _localProducts[idx].copyWith(
          quantity: newStock,
          updatedAt: now,
        );
      }
      final allIdx = _allProducts.indexWhere((p) => p.id == item.product.id);
      if (allIdx != -1) {
        _allProducts[allIdx] = _allProducts[allIdx].copyWith(
          quantity: newStock,
          updatedAt: now,
        );
      }

      await _recordMovement(movement);

      if (!_isLocalMode && _client != null) {
        try {
          await _client!
              .from(AppConstants.tableProducts)
              .update({'quantity': newStock})
              .eq('id', item.product.id);
        } catch (e) {
          debugPrint('Aviso: falha ao sincronizar item do carrinho ($e), enfileirando offline.');
          await LocalCacheService.instance.queueSyncAction({
            'action_type': 'quick_adjust',
            'product_id': item.product.id,
            'new_quantity': newStock,
            'movement': movement.toMap(),
          });
        }
      }
    }

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);

    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
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

  Future<void> bulkAddProductsToMasterCategory({
    required List<String> productIds,
    required String targetMasterCategoryId,
    required String pin,
  }) async {
    if (productIds.isEmpty) return;

    final operatorPin = await validatePin(pin);
    if (operatorPin == null || !operatorPin.isMasterPin) {
      throw Exception('Apenas operadores com PIN Mestre têm permissão para adicionar produtos a setores.');
    }

    final catId = targetMasterCategoryId.toLowerCase().trim();
    if (_isLocalMode || _client == null) {
      for (final id in productIds) {
        final index = _localProducts.indexWhere((p) => p.id == id);
        if (index != -1) {
          final current = List<String>.from(_localProducts[index].masterCategories);
          if (!current.contains(catId)) {
            current.add(catId);
          }
          if (catId != 'outros' && current.contains('outros')) {
            current.remove('outros');
          }
          _localProducts[index] = _localProducts[index].copyWith(
            masterCategories: current,
            updatedAt: DateTime.now(),
          );
        }
      }
      await LocalCacheService.instance.saveProducts(_localProducts);
      _notifyLocal();
      return;
    }

    // Atualiza localmente primeiro
    for (final id in productIds) {
      final pIdx = _allProducts.indexWhere((p) => p.id == id);
      List<String> current = [];
      if (pIdx != -1) {
        current = List<String>.from(_allProducts[pIdx].masterCategories);
      }
      if (!current.contains(catId)) {
        current.add(catId);
      }
      if (catId != 'outros' && current.contains('outros')) {
        current.remove('outros');
      }

      if (pIdx != -1) {
        _allProducts[pIdx] = _allProducts[pIdx].copyWith(masterCategories: current);
      }

      try {
        await _client!
            .from(AppConstants.tableProducts)
            .update({'master_categories': current})
            .eq('id', id);
      } catch (e) {
        debugPrint('Aviso: falha de rede ao adicionar categoria mestre no Supabase: $e');
        await LocalCacheService.instance.queueSyncAction({
          'action_type': 'bulk_add_master_cat',
          'product_id': id,
          'master_categories': current,
        });
      }
    }

    await LocalCacheService.instance.saveProducts(_allProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts));
    }
  }

  Future<void> bulkRemoveProductsFromMasterCategory({
    required List<String> productIds,
    required String targetMasterCategoryId,
    required String pin,
  }) async {
    if (productIds.isEmpty) return;

    final operatorPin = await validatePin(pin);
    if (operatorPin == null || !operatorPin.isMasterPin) {
      throw Exception('Apenas operadores com PIN Mestre têm permissão para remover produtos de setores.');
    }

    final catId = targetMasterCategoryId.toLowerCase().trim();
    if (_isLocalMode || _client == null) {
      for (final id in productIds) {
        final index = _localProducts.indexWhere((p) => p.id == id);
        if (index != -1) {
          final current = List<String>.from(_localProducts[index].masterCategories);
          current.remove(catId);
          if (current.isEmpty) {
            current.add('outros');
          }
          _localProducts[index] = _localProducts[index].copyWith(
            masterCategories: current,
            updatedAt: DateTime.now(),
          );
        }
      }
      await LocalCacheService.instance.saveProducts(_localProducts);
      _notifyLocal();
      return;
    }

    // Atualiza localmente e tenta sincronizar com Supabase
    for (final id in productIds) {
      final pIdx = _allProducts.indexWhere((p) => p.id == id);
      List<String> current = [];
      if (pIdx != -1) {
        current = List<String>.from(_allProducts[pIdx].masterCategories);
      }
      current.remove(catId);
      if (current.isEmpty) {
        current.add('outros');
      }

      if (pIdx != -1) {
        _allProducts[pIdx] = _allProducts[pIdx].copyWith(masterCategories: current);
      }

      try {
        await _client!
            .from(AppConstants.tableProducts)
            .update({'master_categories': current})
            .eq('id', id);
      } catch (e) {
        debugPrint('Aviso: falha de rede ao remover categoria mestre no Supabase: $e');
        await LocalCacheService.instance.queueSyncAction({
          'action_type': 'bulk_remove_master_cat',
          'product_id': id,
          'master_categories': current,
        });
      }
    }

    await LocalCacheService.instance.saveProducts(_allProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts));
    }
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
          final merged = serverMovement.copyWith(
            notes: serverMovement.notes ?? movement.notes,
          );
          if (idx != -1) {
            _localMovements[idx] = merged;
          } else {
            _localMovements.insert(0, merged);
          }
          if (!_movementsStreamController.isClosed) {
            _movementsStreamController.add(List.unmodifiable(_localMovements));
          }
        }
      } catch (e) {
        debugPrint('Aviso: falha ao gravar stock_movements no Supabase: $e');
        // Fallback defensivo: se falhar com notes ou product_id (por FK, tipo UUID ou coluna inexistente)
        try {
          final fallbackPayload = movement.toMap(forDatabaseInsert: true);
          if (e.toString().contains('notes') ||
              e.toString().contains('42703') ||
              e.toString().contains('PGRST204')) {
            fallbackPayload.remove('notes');
          }
          fallbackPayload['product_id'] = null;
          final res = await _client!
              .from('stock_movements')
              .insert(fallbackPayload)
              .select()
              .maybeSingle();
          if (res != null) {
            final serverMovement = StockMovementModel.fromMap(res);
            final idx = _localMovements.indexOf(movement);
            final merged = serverMovement.copyWith(
              notes: serverMovement.notes ?? movement.notes,
            );
            if (idx != -1) {
              _localMovements[idx] = merged;
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
