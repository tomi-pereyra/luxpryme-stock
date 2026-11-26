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
    OperatorPinModel.customSectorNameResolver = (sectorId) {
      final found = _masterCategories.where(
        (m) => m.id.toLowerCase() == sectorId.toLowerCase(),
      );
      return found.isNotEmpty ? found.first.name : null;
    };
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
  List<ProductModel> _trashProducts = [];
  List<StockConflictModel> _conflicts = [];

  final _categoriesStreamController =
      StreamController<List<CategoryModel>>.broadcast();
  final _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();
  final _trashStreamController =
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

  List<ProductModel> get currentTrashProducts =>
      List.unmodifiable(_trashProducts);

  Stream<List<ProductModel>> streamTrashProducts() {
    Timer.run(() {
      if (!_trashStreamController.isClosed) {
        _trashStreamController.add(List.unmodifiable(_trashProducts));
      }
    });
    return _trashStreamController.stream;
  }

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

      final cachedTrash = await LocalCacheService.instance.loadTrash();
      if (cachedTrash != null && cachedTrash.isNotEmpty) {
        _trashProducts = cachedTrash;
        if (!_trashStreamController.isClosed) {
          _trashStreamController.add(List.unmodifiable(_trashProducts));
        }
      }

      _isCacheLoaded = true;
      if (!_isLocalMode && _client != null) {
        unawaited(fetchOperatorPins());
      }
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
        id: '687fa9ba-ddcd-4b27-9258-6823c6ea0254',
        name: 'Claumir (Gerente Operacional)',
        pin: '2026',
        masterCategory: 'todas',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: '64abbd58-9a29-4b6f-8c7b-78d882099e2c',
        name: 'Tomas (Supervisor de Eletrônica)',
        pin: '4464',
        masterCategory: 'todas',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: '5a77a99d-6d9b-4b3b-b97c-18dc76812917',
        name: 'Roberto (Monitor SMD)',
        pin: '1830',
        masterCategory: 'eletronica',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: '1c6313e1-811d-4006-8b81-63c7ff2027a3',
        name: 'Novachelande (Monitora PTH)',
        pin: '1206',
        masterCategory: 'eletronica',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      OperatorPinModel(
        id: '3ba49c13-7611-40d8-9287-4ba0fef2fd3d',
        name: 'Julia',
        pin: '4512',
        masterCategory: 'eletronica',
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
    } else if (_client != null) {
      unawaited(fetchOperatorPins());
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
  // CATEGORIAS (LOCAL-FIRST + SINCRONIZAÇÃO EM SEGUNDO PLANO)
  // ---------------------------------------------------------------------------

  RealtimeChannel? _categoriesRealtimeChannel;

  List<CategoryModel> get currentCategories => List.unmodifiable(_localCategories);

  /// Retorna apenas as categorias cadastradas/vinculadas ao setor informado.
  /// Se [sectorId] for 'todas', retorna todas as categorias ordenadas por nome.
  List<CategoryModel> getCategoriesForSector(
    String sectorId, {
    List<CategoryModel>? allCategories,
    List<ProductModel>? products,
    bool? onlyArchived,
  }) {
    final cats = List<CategoryModel>.from(allCategories ?? _localCategories);
    cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final cleanSector = sectorId.trim().toLowerCase();
    if (cleanSector.isEmpty || cleanSector == 'todas') {
      return cats;
    }

    final sourceProducts = products ?? currentProducts;
    final usedCatIds = <String>{};
    for (final p in sourceProducts) {
      if (onlyArchived != null && p.isArchived != onlyArchived) continue;
      if (p.masterCategories.any((m) => m.toLowerCase() == cleanSector)) {
        usedCatIds.addAll(p.categoryIds);
      }
    }

    return cats.where((cat) {
      if (usedCatIds.contains(cat.id)) return true;
      if (onlyArchived != true &&
          cat.masterCategories.any((m) => m.toLowerCase() == cleanSector)) {
        return true;
      }
      return false;
    }).toList();
  }

  Stream<List<CategoryModel>> streamCategories() {
    scheduleMicrotask(() {
      if (!_categoriesStreamController.isClosed) {
        _categoriesStreamController.add(List.unmodifiable(_localCategories));
      }
    });

    if (!_isLocalMode && _client != null) {
      fetchCategories();
      _subscribeCategoriesRealtime();
    }

    return _categoriesStreamController.stream;
  }

  void _subscribeCategoriesRealtime() {
    if (_categoriesRealtimeChannel != null || _client == null) return;

    _categoriesRealtimeChannel = _client!
        .channel('public:categories_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tableCategories,
          callback: (payload) {
            fetchCategories();
          },
        )
        .subscribe();
  }

  Future<List<CategoryModel>> fetchCategories({bool throwOnError = false}) async {
    if (_isLocalMode || _client == null) {
      return List.unmodifiable(_localCategories);
    }

    try {
      final res = await _client!
          .from(AppConstants.tableCategories)
          .select()
          .order('name', ascending: true);

      final remoteList = (res as List)
          .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
          .toList();

      // Preserva metadados locais (ex: subcategorias ou setores locais caso o banco não tenha retornado)
      final existingById = {for (final c in _localCategories) c.id: c};
      final merged = remoteList.map((rc) {
        final prev = existingById[rc.id];
        if (prev == null) return rc;
        return rc.copyWith(
          subcategories: rc.subcategories.isNotEmpty ? rc.subcategories : prev.subcategories,
          masterCategories: rc.masterCategories.isNotEmpty ? rc.masterCategories : prev.masterCategories,
        );
      }).toList();

      // Preserva categorias criadas offline ainda não sincronizadas
      for (final localC in _localCategories) {
        if (localC.id.startsWith('cat-') &&
            !merged.any((m) => m.name.trim().toLowerCase() == localC.name.trim().toLowerCase())) {
          merged.add(localC);
        }
      }

      merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _localCategories = merged;
      await LocalCacheService.instance.saveCategories(_localCategories);
      if (!_categoriesStreamController.isClosed) {
        _categoriesStreamController.add(List.unmodifiable(_localCategories));
      }
      return List.unmodifiable(_localCategories);
    } catch (e) {
      debugPrint('Aviso ao carregar categorias do Supabase: $e');
      if (throwOnError) rethrow;
      return List.unmodifiable(_localCategories);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
    List<String> masterCategories = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Informe o nome da categoria.');
    }
    if (_localCategories.any((c) => c.name.trim().toLowerCase() == cleanName.toLowerCase())) {
      throw Exception('Já existe uma categoria cadastrada com o nome "$cleanName".');
    }

    final cleanSectors = masterCategories
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty && s != 'todas')
        .toSet()
        .toList();

    final newCat = CategoryModel(
      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      masterCategories: cleanSectors,
      createdAt: DateTime.now(),
    );

    _localCategories.add(newCat);
    _localCategories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await LocalCacheService.instance.saveCategories(_localCategories);
    if (!_categoriesStreamController.isClosed) {
      _categoriesStreamController.add(List.unmodifiable(_localCategories));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return newCat;
    }

    unawaited(_backgroundSyncCreateCategory(newCat));
    return newCat;
  }

  Future<void> _backgroundSyncCreateCategory(CategoryModel newCat) async {
    if (_client == null || _isLocalMode) return;
    try {
      final supaDesc = newCat.toSupabaseDescription();
      final res = await _client!
          .from(AppConstants.tableCategories)
          .insert({
            'name': newCat.name,
            'description': ?supaDesc,
          })
          .select()
          .maybeSingle();

      if (res != null) {
        final serverCat = CategoryModel.fromMap(res).copyWith(
          masterCategories: newCat.masterCategories,
        );
        final idx = _localCategories.indexWhere((c) => c.id == newCat.id || c.name.toLowerCase() == serverCat.name.toLowerCase());
        if (idx != -1) {
          _localCategories[idx] = serverCat;
        } else {
          _localCategories.add(serverCat);
        }
        _localCategories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        await LocalCacheService.instance.saveCategories(_localCategories);
        if (!_categoriesStreamController.isClosed) {
          _categoriesStreamController.add(List.unmodifiable(_localCategories));
        }

        // Reconcilia produtos locais que já usaram o ID temporário da categoria
        if (serverCat.id != newCat.id) {
          bool changedProds = false;
          for (int i = 0; i < _allProducts.length; i++) {
            if (_allProducts[i].categoryIds.contains(newCat.id)) {
              final updatedIds = _allProducts[i]
                  .categoryIds
                  .map((cid) => cid == newCat.id ? serverCat.id : cid)
                  .toList();
              _allProducts[i] = _allProducts[i].copyWith(categoryIds: updatedIds);
              changedProds = true;
            }
          }
          for (int i = 0; i < _localProducts.length; i++) {
            if (_localProducts[i].categoryIds.contains(newCat.id)) {
              final updatedIds = _localProducts[i]
                  .categoryIds
                  .map((cid) => cid == newCat.id ? serverCat.id : cid)
                  .toList();
              _localProducts[i] = _localProducts[i].copyWith(categoryIds: updatedIds);
              changedProds = true;
            }
          }
          if (changedProds) {
            await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
            if (!_productsStreamController.isClosed) {
              _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar criação de categoria em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'create_category',
        'category': newCat.toMap(),
      });
    }
  }

  Future<CategoryModel> updateCategory({
    required String id,
    required String name,
    String? description,
    List<String>? masterCategories,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('O nome da categoria não pode ser vazio.');
    }

    final idx = _localCategories.indexWhere((c) => c.id == id);
    if (idx == -1) {
      throw Exception('Categoria não encontrada.');
    }

    final duplicate = _localCategories.any(
      (c) => c.id != id && c.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );
    if (duplicate) {
      throw Exception('Já existe outra categoria com o nome "$cleanName".');
    }

    final existing = _localCategories[idx];
    final cleanDesc = description?.trim();
    final updated = existing.copyWith(
      name: cleanName,
      description: cleanDesc,
      clearDescription: cleanDesc == null || cleanDesc.isEmpty,
      masterCategories: masterCategories != null
          ? masterCategories
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty && s != 'todas')
              .toSet()
              .toList()
          : existing.masterCategories,
    );

    _localCategories[idx] = updated;
    _localCategories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await LocalCacheService.instance.saveCategories(_localCategories);
    if (!_categoriesStreamController.isClosed) {
      _categoriesStreamController.add(List.unmodifiable(_localCategories));
    }

    // Atualiza nomes resolvidos nos produtos em memória imediatamente (0ms)
    final catMap = {for (final c in _localCategories) c.id: c.name};
    bool prodsUpdated = false;
    for (int i = 0; i < _allProducts.length; i++) {
      if (_allProducts[i].categoryIds.contains(id)) {
        final names = _allProducts[i]
            .categoryIds
            .map((cid) => catMap[cid])
            .whereType<String>()
            .toList();
        _allProducts[i] = _allProducts[i].copyWith(categoryNames: names);
        prodsUpdated = true;
      }
    }
    for (int i = 0; i < _localProducts.length; i++) {
      if (_localProducts[i].categoryIds.contains(id)) {
        final names = _localProducts[i]
            .categoryIds
            .map((cid) => catMap[cid])
            .whereType<String>()
            .toList();
        _localProducts[i] = _localProducts[i].copyWith(categoryNames: names);
        prodsUpdated = true;
      }
    }
    if (prodsUpdated) {
      await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
      }
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return updated;
    }

    unawaited(_backgroundSyncUpdateCategory(updated));
    return updated;
  }

  Future<void> _backgroundSyncUpdateCategory(CategoryModel updated) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!
          .from(AppConstants.tableCategories)
          .update({
            'name': updated.name,
            'description': updated.toSupabaseDescription(),
          })
          .eq('id', updated.id);
    } catch (e) {
      debugPrint('Aviso ao sincronizar atualização de categoria em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'update_category',
        'category': updated.toMap(),
      });
    }
  }

  /// Elimina uma categoria mesmo que existam produtos vinculados a ela,
  /// desvinculando automaticamente esses produtos localmente (0ms) e em segundo plano no Supabase.
  Future<int> deleteCategory(String categoryId) async {
    _localCategories.removeWhere((c) => c.id == categoryId);
    await LocalCacheService.instance.saveCategories(_localCategories);
    if (!_categoriesStreamController.isClosed) {
      _categoriesStreamController.add(List.unmodifiable(_localCategories));
    }

    final catMap = {for (final c in _localCategories) c.id: c.name};
    final List<ProductModel> affectedProducts = [];
    final seenIds = <String>{};

    for (int i = 0; i < _allProducts.length; i++) {
      final p = _allProducts[i];
      if (p.categoryIds.contains(categoryId)) {
        final newIds = p.categoryIds.where((cid) => cid != categoryId).toList();
        final newNames = newIds.map((cid) => catMap[cid]).whereType<String>().toList();
        final updatedP = p.copyWith(
          categoryIds: newIds,
          categoryNames: newNames,
          updatedAt: DateTime.now(),
        );
        _allProducts[i] = updatedP;
        if (seenIds.add(updatedP.id)) {
          affectedProducts.add(updatedP);
        }
      }
    }

    for (int i = 0; i < _localProducts.length; i++) {
      final p = _localProducts[i];
      if (p.categoryIds.contains(categoryId)) {
        final newIds = p.categoryIds.where((cid) => cid != categoryId).toList();
        final newNames = newIds.map((cid) => catMap[cid]).whereType<String>().toList();
        final updatedP = p.copyWith(
          categoryIds: newIds,
          categoryNames: newNames,
          updatedAt: DateTime.now(),
        );
        _localProducts[i] = updatedP;
        if (seenIds.add(updatedP.id)) {
          affectedProducts.add(updatedP);
        }
      }
    }

    bool trashChanged = false;
    for (int i = 0; i < _trashProducts.length; i++) {
      final p = _trashProducts[i];
      if (p.categoryIds.contains(categoryId)) {
        final newIds = p.categoryIds.where((cid) => cid != categoryId).toList();
        final newNames = newIds.map((cid) => catMap[cid]).whereType<String>().toList();
        _trashProducts[i] = p.copyWith(categoryIds: newIds, categoryNames: newNames);
        trashChanged = true;
      }
    }
    if (trashChanged) {
      await LocalCacheService.instance.saveTrash(_trashProducts);
      if (!_trashStreamController.isClosed) {
        _trashStreamController.add(List.unmodifiable(_trashProducts));
      }
    }

    if (affectedProducts.isNotEmpty) {
      await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
      }
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return affectedProducts.length;
    }

    unawaited(_backgroundSyncDeleteCategory(categoryId, affectedProducts));
    return affectedProducts.length;
  }

  Future<void> _backgroundSyncDeleteCategory(
    String categoryId,
    List<ProductModel> affectedProducts,
  ) async {
    if (_client == null || _isLocalMode) return;
    try {
      for (final prod in affectedProducts) {
        if (!ProductModel.uuidRegex.hasMatch(prod.id)) continue;
        final validCatIds = prod.categoryIds.where((c) => ProductModel.uuidRegex.hasMatch(c)).toList();
        await _client!
            .from(AppConstants.tableProducts)
            .update({
              'category_ids': validCatIds,
              'category_id': validCatIds.isNotEmpty ? validCatIds.first : null,
            })
            .eq('id', prod.id);
      }

      if (ProductModel.uuidRegex.hasMatch(categoryId)) {
        await _client!
            .from(AppConstants.tableCategories)
            .delete()
            .eq('id', categoryId);
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar exclusão de categoria em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'delete_category',
        'category_id': categoryId,
        'affected_products': affectedProducts.map((p) => {
          'id': p.id,
          'category_ids': p.categoryIds,
        }).toList(),
      });
    }
  }

  /// Troca a categoria de múltiplos produtos selecionados localmente (0ms) e sincroniza em segundo plano com o Supabase.
  Future<int> bulkChangeProductsCategory({
    required List<String> productIds,
    required String? sourceCategoryId,
    required String? targetCategoryId,
  }) async {
    if (productIds.isEmpty) return 0;

    final idSet = productIds.toSet();
    final catMap = {for (final c in _localCategories) c.id: c.name};
    final List<ProductModel> affectedProducts = [];
    final seenIds = <String>{};

    List<String> computeNewCatIds(List<String> currentIds) {
      final updated = List<String>.from(currentIds);
      if (sourceCategoryId != null && sourceCategoryId.isNotEmpty) {
        updated.removeWhere((cid) => cid == sourceCategoryId);
      } else {
        updated.clear();
      }
      if (targetCategoryId != null &&
          targetCategoryId.isNotEmpty &&
          !updated.contains(targetCategoryId)) {
        updated.add(targetCategoryId);
      }
      return updated;
    }

    for (int i = 0; i < _allProducts.length; i++) {
      final p = _allProducts[i];
      if (idSet.contains(p.id)) {
        final newIds = computeNewCatIds(p.categoryIds);
        final newNames = newIds.map((cid) => catMap[cid]).whereType<String>().toList();
        final updatedP = p.copyWith(
          categoryIds: newIds,
          categoryNames: newNames,
          updatedAt: DateTime.now(),
        );
        _allProducts[i] = updatedP;
        if (seenIds.add(updatedP.id)) {
          affectedProducts.add(updatedP);
        }
      }
    }

    for (int i = 0; i < _localProducts.length; i++) {
      final p = _localProducts[i];
      if (idSet.contains(p.id)) {
        final newIds = computeNewCatIds(p.categoryIds);
        final newNames = newIds.map((cid) => catMap[cid]).whereType<String>().toList();
        final updatedP = p.copyWith(
          categoryIds: newIds,
          categoryNames: newNames,
          updatedAt: DateTime.now(),
        );
        _localProducts[i] = updatedP;
        if (seenIds.add(updatedP.id)) {
          affectedProducts.add(updatedP);
        }
      }
    }

    if (affectedProducts.isNotEmpty) {
      await LocalCacheService.instance.saveProducts(
        _allProducts.isNotEmpty ? _allProducts : _localProducts,
      );
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(
          List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts),
        );
      }
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return affectedProducts.length;
    }

    for (final prod in affectedProducts) {
      unawaited(_backgroundSyncUpdateProduct(prod));
    }
    return affectedProducts.length;
  }

  // ---------------------------------------------------------------------------
  // CATEGORIAS MESTRES INDUSTRIAIS (SETORES: ELETRÔNICA, PRODUÇÃO, ETC.)
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

  Future<List<MasterCategoryModel>> fetchMasterCategories({bool throwOnError = false}) async {
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
      if (throwOnError) rethrow;
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

    // Atualiza memória e persistência local imediatamente (0ms)
    _masterCategories.add(newMaster);
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }

    // Sincronização em segundo plano com o Supabase
    if (!_isLocalMode && _client != null) {
      unawaited(_backgroundSyncUpsertMasterCategory(newMaster));
    }

    return newMaster;
  }

  Future<void> _backgroundSyncUpsertMasterCategory(MasterCategoryModel masterCat) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!.from(AppConstants.tableMasterCategories).upsert({
        'id': masterCat.id,
        'name': masterCat.name,
        'description': masterCat.description,
        'color': masterCat.colorHex,
        'icon': masterCat.iconName,
      });
    } catch (e) {
      debugPrint('Aviso ao sincronizar master_category no Supabase em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'upsert_master_category',
        'master_category': masterCat.toMap(),
      });
    }
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

    // Atualiza imediatamente localmente (0ms)
    _masterCategories[index] = updated;
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }
    if (!_pinsStreamController.isClosed) {
      _pinsStreamController.add(List.unmodifiable(_localPins));
    }

    // Sincronização em segundo plano com o Supabase
    if (!_isLocalMode && _client != null) {
      unawaited(_backgroundSyncUpsertMasterCategory(updated));
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
        final updatedP = p.copyWith(masterCategories: newCats);
        _allProducts[i] = updatedP;
        if (!_isLocalMode && _client != null) {
          unawaited(_backgroundSyncUpdateProduct(updatedP));
        }
      }
    }
    for (int i = 0; i < _localProducts.length; i++) {
      final p = _localProducts[i];
      if (p.masterCategories.contains(lowerId)) {
        final newCats = List<String>.from(p.masterCategories)..remove(lowerId);
        if (newCats.isEmpty) newCats.add('outros');
        _localProducts[i] = p.copyWith(masterCategories: newCats);
      }
    }
    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    // Se houver algum PIN vinculado exclusivamente a essa categoria, migra para 'outros'
    for (int i = 0; i < _localPins.length; i++) {
      if (_localPins[i].masterCategory.toLowerCase() == lowerId) {
        _localPins[i] = _localPins[i].copyWith(masterCategory: 'outros');
      }
    }
    await LocalCacheService.instance.savePins(_localPins);

    _masterCategories.removeWhere((mc) => mc.id.toLowerCase() == lowerId);
    _saveMasterCategoriesLocal();
    if (!_masterCategoriesStreamController.isClosed) {
      _masterCategoriesStreamController.add(List.unmodifiable(_masterCategories));
    }

    if (!_isLocalMode && _client != null) {
      unawaited(_backgroundSyncDeleteMasterCategory(id, lowerId));
    }
  }

  Future<void> _backgroundSyncDeleteMasterCategory(String id, String lowerId) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!
          .from('operator_pins')
          .update({'master_category': 'outros'})
          .eq('master_category', lowerId);
    } catch (_) {}

    try {
      await _client!.from(AppConstants.tableMasterCategories).delete().eq('id', id);
    } catch (e) {
      debugPrint('Aviso ao remover master_category do Supabase em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'delete_master_category',
        'id': id,
        'lower_id': lowerId,
      });
    }
  }

  void _saveMasterCategoriesLocal() {
    unawaited(LocalCacheService.instance.saveMasterCategories(_masterCategories));
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
      List.unmodifiable(_isLocalMode || _client == null ? _localProducts : (_allProducts.isNotEmpty ? _allProducts : _localProducts));

  List<ProductModel> get activeProducts =>
      currentProducts.where((p) => !p.isArchived).toList();

  List<ProductModel> get archivedProducts =>
      currentProducts.where((p) => p.isArchived).toList();

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

  Future<void> _flushPendingSyncQueue({bool rethrowOnError = false}) async {
    if (_isFlushingQueue || _isLocalMode || _client == null) return;
    _isFlushingQueue = true;
    try {
      final queue = await LocalCacheService.instance.loadPendingSyncActions();
      if (queue.isEmpty) return;

      debugPrint('Sincronizando ${queue.length} ações pendentes da fila offline...');
      final List<Map<String, dynamic>> failedActions = [];
      Object? lastError;

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
              await _client!.from(AppConstants.tableProducts).insert(prod.toMap(forDatabaseInsert: true));
              break;

            case 'update_product':
              final productMap = Map<String, dynamic>.from(action['product']);
              final prod = ProductModel.fromMap(productMap);
              if (ProductModel.uuidRegex.hasMatch(prod.id)) {
                final uPayload = prod.toMap(forSupabase: true);
                await _client!
                    .from(AppConstants.tableProducts)
                    .update(uPayload)
                    .eq('id', prod.id);
              }
              break;

            case 'delete_product':
              final pId = action['product_id']?.toString();
              if (pId != null && ProductModel.uuidRegex.hasMatch(pId)) {
                await _client!.from(AppConstants.tableProducts).delete().eq('id', pId);
              }
              break;

            case 'restore_product':
              final productMap = Map<String, dynamic>.from(action['product']);
              final prod = ProductModel.fromMap(productMap);
              final rPayload = prod.toMap(forSupabase: true);
              if (ProductModel.uuidRegex.hasMatch(prod.id)) {
                rPayload['id'] = prod.id;
              }
              await _client!.from(AppConstants.tableProducts).upsert(rPayload);
              break;

            case 'bulk_add_master_cat':
            case 'bulk_remove_master_cat':
            case 'move_master_cat':
              final pId = action['product_id']?.toString();
              final mCats = (action['master_categories'] as List?)?.map((e) => e.toString()).toList();
              if (pId != null && mCats != null && ProductModel.uuidRegex.hasMatch(pId)) {
                await _client!
                    .from(AppConstants.tableProducts)
                    .update({'master_categories': mCats})
                    .eq('id', pId);
              }
              break;

            case 'resolve_conflict':
              final pId = action['product_id']?.toString();
              final qty = action['quantity'] as int?;
              if (pId != null && qty != null && ProductModel.uuidRegex.hasMatch(pId)) {
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

            case 'create_category':
              final catMap = Map<String, dynamic>.from(action['category']);
              final cat = CategoryModel.fromMap(catMap);
              final supaDesc = cat.toSupabaseDescription();
              await _client!.from(AppConstants.tableCategories).insert({
                'name': cat.name,
                'description': ?supaDesc,
              });
              break;

            case 'update_category':
              final catMap = Map<String, dynamic>.from(action['category']);
              final cat = CategoryModel.fromMap(catMap);
              if (ProductModel.uuidRegex.hasMatch(cat.id)) {
                await _client!.from(AppConstants.tableCategories).update({
                  'name': cat.name,
                  'description': cat.toSupabaseDescription(),
                }).eq('id', cat.id);
              }
              break;

            case 'delete_category':
              final catId = action['category_id']?.toString();
              final List affected = action['affected_products'] as List? ?? [];
              for (final item in affected) {
                final m = Map<String, dynamic>.from(item);
                final pId = m['id']?.toString();
                if (pId != null && ProductModel.uuidRegex.hasMatch(pId)) {
                  final cIds = (m['category_ids'] as List? ?? [])
                      .map((e) => e.toString())
                      .where((c) => ProductModel.uuidRegex.hasMatch(c))
                      .toList();
                  await _client!.from(AppConstants.tableProducts).update({
                    'category_ids': cIds,
                    'category_id': cIds.isNotEmpty ? cIds.first : null,
                  }).eq('id', pId);
                }
              }
              if (catId != null && ProductModel.uuidRegex.hasMatch(catId)) {
                await _client!.from(AppConstants.tableCategories).delete().eq('id', catId);
              }
              break;

            case 'upsert_master_category':
              final mcMap = Map<String, dynamic>.from(action['master_category']);
              final mc = MasterCategoryModel.fromMap(mcMap);
              await _client!.from(AppConstants.tableMasterCategories).upsert({
                'id': mc.id,
                'name': mc.name,
                'description': mc.description,
                'color': mc.colorHex,
                'icon': mc.iconName,
              });
              break;

            case 'delete_master_category':
              final mcId = action['id']?.toString();
              final lowerId = action['lower_id']?.toString();
              if (lowerId != null) {
                try {
                  await _client!
                      .from('operator_pins')
                      .update({'master_category': 'outros'})
                      .eq('master_category', lowerId);
                } catch (_) {}
              }
              if (mcId != null) {
                await _client!.from(AppConstants.tableMasterCategories).delete().eq('id', mcId);
              }
              break;

            case 'create_operator_pin':
              final pinMap = Map<String, dynamic>.from(action['pin']);
              await _client!.from('operator_pins').upsert({
                'name': pinMap['name'],
                'pin': pinMap['pin'],
                'master_category': pinMap['master_category'],
                'is_active': true,
              }, onConflict: 'pin');
              break;

            case 'update_operator_pin':
              final pinMap = Map<String, dynamic>.from(action['pin']);
              final pId = pinMap['id']?.toString();
              if (pId != null && ProductModel.uuidRegex.hasMatch(pId)) {
                await _client!.from('operator_pins').update({
                  'name': pinMap['name'],
                  'pin': pinMap['pin'],
                  'master_category': pinMap['master_category'],
                }).eq('id', pId);
              }
              break;

            case 'delete_operator_pin':
              final pId = action['id']?.toString();
              if (pId != null && ProductModel.uuidRegex.hasMatch(pId)) {
                await _client!.from('operator_pins').delete().eq('id', pId);
              }
              break;
          }
        } catch (itemErr) {
          debugPrint('Aviso ao sincronizar item da fila offline ($type): $itemErr');
          lastError = itemErr;
          failedActions.add(action);
        }
      }

      if (failedActions.isEmpty) {
        await LocalCacheService.instance.clearPendingSyncActions();
        debugPrint('Fila offline descarregada com sucesso.');
      } else {
        await LocalCacheService.instance.savePendingSyncActions(failedActions);
        if (rethrowOnError && lastError != null) {
          throw Exception('Falha de rede ao enviar ${failedActions.length} alteração(ões) pendente(s): $lastError');
        }
      }
    } catch (e) {
      debugPrint('Aviso ao descarregar fila offline: $e');
      if (rethrowOnError) rethrow;
    } finally {
      _isFlushingQueue = false;
    }
  }

  /// Sincronização completa e garantida com o Supabase (descarrega fila local e atualiza todas as tabelas).
  /// Lança exceção caso não haja conexão, evitando avisos falsos de sucesso.
  Future<void> syncAllWithSupabase() async {
    if (_isLocalMode || _client == null) {
      throw Exception('Aplicativo em modo offline/local sem conexão com o Supabase.');
    }

    // 1. Aguarda caso já haja um carregamento em andamento para não retornar cache antigo
    int waitCycles = 0;
    while (_isLoadingProducts && waitCycles < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCycles++;
    }

    // 2. Descarrega fila local pendente primeiro para não sobrescrever edições locais
    await _flushPendingSyncQueue(rethrowOnError: true);

    // 3. Baixa categorias, setores e PINs atualizados do servidor
    await Future.wait([
      fetchCategories(throwOnError: true),
      fetchMasterCategories(throwOnError: true),
      fetchOperatorPins(),
    ]);

    // 4. Baixa o catálogo completo de produtos (ativos e arquivados) com validação real de erro
    await _executeProductsFetch(throwOnError: true);

    // 5. Atualiza movimentações em segundo plano
    unawaited(fetchMovements());
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

    return _executeProductsFetch(throwOnError: forceRefresh);
  }

  Future<List<ProductModel>> _executeProductsFetch({bool throwOnError = false}) async {
    if (_isLoadingProducts) return _allProducts;
    _isLoadingProducts = true;

    try {
      // 1. Descarrega qualquer alteração offline pendente
      await _flushPendingSyncQueue(rethrowOnError: throwOnError);

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

      // Preserva quaisquer produtos recém-criados localmente ou pendentes de sincronização
      for (final localP in _allProducts) {
        if (localP.id.startsWith('prod-') &&
            !loaded.any((p) => p.name.trim().toLowerCase() == localP.name.trim().toLowerCase())) {
          loaded.insert(0, localP);
        }
      }

      // Garante que produtos que estão na lixeira não reapareçam no estoque ativo
      loaded.removeWhere((p) => _trashProducts.any((t) => t.id == p.id));

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
      if (throwOnError) rethrow;
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

    _conflicts.removeWhere((c) => c.id == conflictId || c.productId == productId);
    await LocalCacheService.instance.saveConflicts(_conflicts);
    if (!_conflictsStreamController.isClosed) {
      _conflictsStreamController.add(List.unmodifiable(_conflicts));
    }

    if (!_isLocalMode && _client != null) {
      unawaited(_backgroundSyncResolveConflict(productId, newQuantity, movement));
    }
  }

  Future<void> _backgroundSyncResolveConflict(
    String productId,
    int newQuantity,
    StockMovementModel movement,
  ) async {
    if (_client == null || _isLocalMode) return;
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
              _allProducts.removeWhere((p) =>
                  p.id == newP.id ||
                  (p.id.startsWith('prod-') &&
                      p.name.trim().toLowerCase() == newP.name.trim().toLowerCase()));
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

    String operatorName = 'Operador (Sem PIN)';
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

    final tempId = product.id.isNotEmpty
        ? product.id
        : 'prod-${DateTime.now().millisecondsSinceEpoch}';

    final newProduct = product.copyWith(
      id: tempId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _allProducts.removeWhere((p) => p.id == newProduct.id);
    _allProducts.insert(0, newProduct);
    _allProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _localProducts.removeWhere((p) => p.id == newProduct.id);
    _localProducts.insert(0, newProduct);
    _localProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts));
    }
    await LocalCacheService.instance.saveProducts(_allProducts);

    StockMovementModel? initialMovement;
    if (newProduct.quantity > 0) {
      initialMovement = StockMovementModel(
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
      await _recordMovement(initialMovement);
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    // Dispara a sincronização com o Supabase em segundo plano sem travar a interface
    unawaited(_backgroundSyncCreateProduct(newProduct, initialMovement, operatorName, pin));
  }

  Future<void> _backgroundSyncCreateProduct(
    ProductModel newProduct,
    StockMovementModel? initialMovement,
    String operatorName,
    String? pin,
  ) async {
    if (_client == null || _isLocalMode) return;

    final payload = newProduct.toMap(forDatabaseInsert: true);
    ProductModel savedProduct = newProduct;
    bool inserted = false;

    try {
      final res = await _client!
          .from(AppConstants.tableProducts)
          .insert(payload)
          .select()
          .maybeSingle();

      if (res != null) {
        savedProduct = ProductModel.fromMap(res, categoryNames: newProduct.categoryNames);
        inserted = true;
      }
    } catch (e) {
      debugPrint('Aviso ao inserir produto no Supabase em segundo plano (tentando fallback): $e');
      // Fallback gracioso caso a coluna subcategories ainda não exista no Supabase
      if (e.toString().contains('subcategories') || e.toString().contains('PGRST204')) {
        payload.remove('subcategories');
        try {
          final res2 = await _client!
              .from(AppConstants.tableProducts)
              .insert(payload)
              .select()
              .maybeSingle();
          if (res2 != null) {
            savedProduct = ProductModel.fromMap(res2, categoryNames: newProduct.categoryNames);
            inserted = true;
          }
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
              final res3 = await _client!
                  .from(AppConstants.tableProducts)
                  .insert(payload)
                  .select()
                  .maybeSingle();
              if (res3 != null) {
                savedProduct = ProductModel.fromMap(res3, categoryNames: newProduct.categoryNames);
                inserted = true;
              }
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

    if (inserted) {
      _allProducts.removeWhere((p) => p.id == newProduct.id || p.id == savedProduct.id);
      _allProducts.insert(0, savedProduct);
      _allProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _localProducts.removeWhere((p) => p.id == newProduct.id || p.id == savedProduct.id);
      _localProducts.insert(0, savedProduct);
      _localProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      await LocalCacheService.instance.saveProducts(_allProducts);
      if (!_productsStreamController.isClosed) {
        _productsStreamController.add(List.unmodifiable(_allProducts));
      }

      if (initialMovement != null && savedProduct.id != newProduct.id) {
        final reconciledMovement = initialMovement.copyWith(productId: savedProduct.id);
        _recordMovement(reconciledMovement);
      }
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

    // Executa a atualização no Supabase em segundo plano
    unawaited(_backgroundSyncUpdateProduct(updated));
  }

  Future<void> _backgroundSyncUpdateProduct(ProductModel updated) async {
    if (_client == null || _isLocalMode) return;
    if (!ProductModel.uuidRegex.hasMatch(updated.id)) return;

    final payload = updated.toMap(forSupabase: true);

    try {
      await _client!
          .from(AppConstants.tableProducts)
          .update(payload)
          .eq('id', updated.id);
    } catch (e) {
      // Fallback gracioso caso a coluna subcategories ainda não exista no Supabase
      if (e.toString().contains('subcategories') || e.toString().contains('PGRST204')) {
        payload.remove('subcategories');
        try {
          await _client!
              .from(AppConstants.tableProducts)
              .update(payload)
              .eq('id', updated.id);
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
                  .eq('id', updated.id);
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

  /// Arquiva um produto (mantém seu saldo, setor e categorias, retirando da listagem ativa)
  Future<ProductModel> archiveProduct(String productId, {String? pin}) async {
    return _setProductArchivedState(productId, archived: true, pin: pin);
  }

  /// Desarquiva um produto, retornando-o imediatamente ao estoque ativo de seu setor
  Future<ProductModel> unarchiveProduct(String productId, {String? pin}) async {
    return _setProductArchivedState(productId, archived: false, pin: pin);
  }

  Future<ProductModel> _setProductArchivedState(
    String productId, {
    required bool archived,
    String? pin,
  }) async {
    ProductModel? targetProduct;
    if (_allProducts.any((p) => p.id == productId)) {
      targetProduct = _allProducts.firstWhere((p) => p.id == productId);
    } else if (_localProducts.any((p) => p.id == productId)) {
      targetProduct = _localProducts.firstWhere((p) => p.id == productId);
    }
    if (targetProduct == null) {
      throw Exception('Produto não encontrado no catálogo.');
    }

    String operatorName = 'Operador (Sem PIN)';
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (!op.canModify(targetProduct)) {
        throw Exception(
          'Acesso negado: O PIN "${op.name}" (${op.masterCategoryLabel}) '
          'não possui autorização para ${archived ? "arquivar" : "desarquivar"} produtos deste setor.',
        );
      }
      operatorName = op.name;
    }

    final updated = targetProduct.copyWith(
      isArchived: archived,
      updatedAt: DateTime.now(),
    );

    final lIdx = _localProducts.indexWhere((p) => p.id == productId);
    if (lIdx != -1) _localProducts[lIdx] = updated;
    final aIdx = _allProducts.indexWhere((p) => p.id == productId);
    if (aIdx != -1) _allProducts[aIdx] = updated;

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    final movement = StockMovementModel(
      id: 'mov-${DateTime.now().microsecondsSinceEpoch}',
      productId: updated.id,
      productName: updated.name,
      productCode: updated.code,
      internalCode: updated.internalCode,
      manufacturerCode: updated.manufacturerCode,
      categoryNames: updated.categoryNames ?? [],
      delta: 0,
      previousQuantity: updated.quantity,
      newQuantity: updated.quantity,
      type: archived ? 'PRODUCT_ARCHIVE' : 'PRODUCT_UNARCHIVE',
      operatorName: operatorName,
      pinUsed: pin != null && pin.isNotEmpty ? '****' : null,
      notes: archived
          ? 'Produto movido para Arquivados'
          : 'Produto desarquivado (retornado ao estoque ativo)',
      createdAt: DateTime.now(),
    );
    await _recordMovement(movement);

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return updated;
    }

    unawaited(_backgroundSyncUpdateProduct(updated));
    return updated;
  }

  Future<void> deleteProduct(String productId, {String? pin}) async {
    // Procura o produto antes de remover para gravar no histórico
    ProductModel? targetProduct;
    if (_localProducts.any((p) => p.id == productId)) {
      targetProduct = _localProducts.firstWhere((p) => p.id == productId);
    } else if (_allProducts.any((p) => p.id == productId)) {
      targetProduct = _allProducts.firstWhere((p) => p.id == productId);
    }

    String operatorName = 'Operador (Sem PIN)';
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

    // Armazena na lixeira local para possibilitar recuperação
    if (targetProduct != null) {
      _trashProducts.removeWhere((p) => p.id == productId);
      _trashProducts.insert(
        0,
        targetProduct.copyWith(
          updatedAt: DateTime.now(),
          notes: 'Excluído por: $operatorName',
        ),
      );
      await LocalCacheService.instance.saveTrash(_trashProducts);
      if (!_trashStreamController.isClosed) {
        _trashStreamController.add(List.unmodifiable(_trashProducts));
      }
    }

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

    unawaited(_backgroundSyncDeleteProduct(productId));
  }

  Future<ProductModel> restoreProduct(String productId, {String? pin}) async {
    final trashIndex = _trashProducts.indexWhere((p) => p.id == productId);
    if (trashIndex == -1) {
      throw Exception('Produto não encontrado na lixeira.');
    }
    final targetProduct = _trashProducts[trashIndex];

    String operatorName = 'Operador (Sem PIN)';
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (!op.canModify(targetProduct)) {
        throw Exception(
          'Acesso negado: O PIN "${op.name}" (${op.masterCategoryLabel}) '
          'não possui autorização para restaurar produtos deste setor.',
        );
      }
      operatorName = op.name;
    }

    // 1. Remove da lixeira
    _trashProducts.removeAt(trashIndex);
    await LocalCacheService.instance.saveTrash(_trashProducts);
    if (!_trashStreamController.isClosed) {
      _trashStreamController.add(List.unmodifiable(_trashProducts));
    }

    // 2. Adiciona de volta aos produtos ativos
    final restoredProduct = targetProduct.copyWith(
      updatedAt: DateTime.now(),
      notes: null,
    );
    _localProducts.insert(0, restoredProduct);
    _allProducts.insert(0, restoredProduct);
    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    // 3. Grava movimentação de restauração no histórico
    final movement = StockMovementModel(
      id: 'mov-${DateTime.now().microsecondsSinceEpoch}',
      productId: restoredProduct.id,
      productName: restoredProduct.name,
      productCode: restoredProduct.code,
      internalCode: restoredProduct.internalCode,
      manufacturerCode: restoredProduct.manufacturerCode,
      categoryNames: restoredProduct.categoryNames ?? [],
      delta: restoredProduct.quantity,
      previousQuantity: 0,
      newQuantity: restoredProduct.quantity,
      type: 'PRODUCT_RESTORE',
      operatorName: operatorName,
      pinUsed: pin != null && pin.isNotEmpty ? '****' : null,
      notes: 'Produto recuperado da Lixeira',
      createdAt: DateTime.now(),
    );
    await _recordMovement(movement);

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return restoredProduct;
    }

    unawaited(_backgroundSyncRestoreProduct(restoredProduct));
    return restoredProduct;
  }

  Future<void> permanentlyDeleteProduct(String productId, {String? pin}) async {
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (!op.canAccessAll) {
        throw Exception('Apenas PIN Administrador pode excluir permanentemente da lixeira.');
      }
    }
    _trashProducts.removeWhere((p) => p.id == productId);
    await LocalCacheService.instance.saveTrash(_trashProducts);
    if (!_trashStreamController.isClosed) {
      _trashStreamController.add(List.unmodifiable(_trashProducts));
    }
  }

  Future<void> emptyTrash({String? pin}) async {
    if (pin != null && pin.isNotEmpty) {
      final op = await validatePin(pin);
      if (op == null) throw Exception('PIN inválido ou não autorizado.');
      if (!op.canAccessAll) {
        throw Exception('Apenas PIN Administrador pode esvaziar a lixeira.');
      }
    }
    _trashProducts.clear();
    await LocalCacheService.instance.saveTrash(_trashProducts);
    if (!_trashStreamController.isClosed) {
      _trashStreamController.add(List.unmodifiable(_trashProducts));
    }
  }

  Future<void> _backgroundSyncRestoreProduct(ProductModel product) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!
          .from(AppConstants.tableProducts)
          .upsert(product.toMap(forDatabaseInsert: false));
    } catch (e) {
      debugPrint('Aviso: offline ao restaurar produto em segundo plano, enfileirando: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'restore_product',
        'product': product.toMap(),
      });
    }
  }

  Future<void> _backgroundSyncDeleteProduct(String productId) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!
          .from(AppConstants.tableProducts)
          .delete()
          .eq('id', productId);
    } catch (e) {
      debugPrint('Aviso: offline ao deletar produto em segundo plano, enfileirando: $e');
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
    String operatorName = 'Ajuste Direto (+/-)';
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

    // Supabase em segundo plano
    unawaited(_backgroundSyncQuickAdjust(product.id, newQuantity, movement));

    return newQuantity;
  }

  Future<void> _backgroundSyncQuickAdjust(
    String productId,
    int newQuantity,
    StockMovementModel movement,
  ) async {
    if (_client == null || _isLocalMode) return;
    try {
      await _client!
          .from(AppConstants.tableProducts)
          .update({'quantity': newQuantity})
          .eq('id', productId);
    } catch (e) {
      debugPrint('Aviso: falha de rede no ajuste unitário em segundo plano, enfileirando ação offline: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'quick_adjust',
        'product_id': productId,
        'new_quantity': newQuantity,
        'movement': movement.toMap(),
      });
    }
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

    // 1. Sempre verifica o cache em memória local primeiro (resposta instantânea 0ms)
    try {
      final local = _localPins.firstWhere(
        (p) => p.pin == cleanPin && p.isActive,
      );
      return local;
    } catch (_) {}

    if (_isLocalMode || _client == null) {
      return null;
    }

    // 2. Se não encontrou no cache local mas está online, busca no Supabase e atualiza o cache
    try {
      final res = await _client!
          .from('operator_pins')
          .select()
          .eq('pin', cleanPin)
          .eq('is_active', true)
          .maybeSingle();

      if (res == null) return null;
      final op = OperatorPinModel.fromMap(res);
      _localPins.removeWhere((p) => p.id == op.id || p.pin == op.pin);
      _localPins.add(op);
      LocalCacheService.instance.savePins(_localPins);
      return op;
    } catch (_) {
      return null;
    }
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
    final List<Map<String, dynamic>> syncItems = [];
    final List<StockMovementModel> movements = [];

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

      movements.add(movement);
      syncItems.add({
        'product_id': item.product.id,
        'new_quantity': newStock,
        'movement': movement.toMap(),
      });

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
    }

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);

    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }
    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    // Sincronização com Supabase totalmente em segundo plano
    unawaited(_backgroundSyncCheckoutCart(syncItems));
  }

  Future<void> _backgroundSyncCheckoutCart(List<Map<String, dynamic>> syncItems) async {
    if (_client == null || _isLocalMode) return;
    for (final it in syncItems) {
      final productId = it['product_id']?.toString();
      final newQuantity = it['new_quantity'] as int?;
      if (productId != null && newQuantity != null) {
        try {
          await _client!
              .from(AppConstants.tableProducts)
              .update({'quantity': newQuantity})
              .eq('id', productId);
        } catch (e) {
          debugPrint('Aviso: falha ao sincronizar item do carrinho em segundo plano ($e), enfileirando offline.');
          await LocalCacheService.instance.queueSyncAction({
            'action_type': 'quick_adjust',
            'product_id': productId,
            'new_quantity': newQuantity,
            if (it['movement'] != null) 'movement': it['movement'],
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GESTÃO DE PINS DE OPERADORES (ADMIN WINDOWS & SINCRONIZAÇÃO EM SEGUNDO PLANO)
  // ---------------------------------------------------------------------------

  Future<List<OperatorPinModel>> fetchOperatorPins() async {
    if (_isLocalMode || _client == null) {
      return List.unmodifiable(_localPins);
    }

    try {
      final records = await _client!
          .from('operator_pins')
          .select()
          .order('name', ascending: true);

      final list = (records as List)
          .map((e) => OperatorPinModel.fromMap(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        _localPins = list;
        if (!_pinsStreamController.isClosed) {
          _pinsStreamController.add(List.unmodifiable(_localPins));
        }
        await LocalCacheService.instance.savePins(_localPins);
      }
      return List.unmodifiable(_localPins);
    } catch (e) {
      debugPrint('Aviso ao sincronizar operator_pins do Supabase: $e');
      return List.unmodifiable(_localPins);
    }
  }

  Stream<List<OperatorPinModel>> streamOperatorPins() {
    if (_isLocalMode || _client == null) {
      Timer.run(() => _pinsStreamController.add(List.unmodifiable(_localPins)));
      return _pinsStreamController.stream;
    }

    // Busca imediatamente via REST para popular o cache local
    fetchOperatorPins();

    return _client!
        .from('operator_pins')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((records) {
          final list = records.map((e) => OperatorPinModel.fromMap(e)).toList();
          _localPins = list;
          LocalCacheService.instance.savePins(_localPins);
          return list;
        });
  }

  Future<void> createOperatorPin({
    required String name,
    required String pin,
    String masterCategory = 'eletronica',
  }) async {
    final cleanName = name.trim();
    final cleanPin = pin.trim();
    if (cleanName.isEmpty) {
      throw Exception('Informe o nome do funcionário ou operador.');
    }
    if (cleanPin.length != 4 || int.tryParse(cleanPin) == null) {
      throw Exception('O PIN deve conter exatamente 4 dígitos numéricos.');
    }
    if (_localPins.any((p) => p.pin == cleanPin)) {
      throw Exception('Este PIN já está cadastrado para outro operador.');
    }

    final newPin = OperatorPinModel(
      id: 'pin-${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      pin: cleanPin,
      masterCategory: masterCategory.toLowerCase(),
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Local-first (0ms)
    _localPins.add(newPin);
    _localPins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await LocalCacheService.instance.savePins(_localPins);
    if (!_pinsStreamController.isClosed) {
      _pinsStreamController.add(List.unmodifiable(_localPins));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    unawaited(_backgroundSyncCreateOperatorPin(newPin));
  }

  Future<void> _backgroundSyncCreateOperatorPin(OperatorPinModel newPin) async {
    if (_client == null || _isLocalMode) return;
    try {
      final res = await _client!.from('operator_pins').insert({
        'name': newPin.name,
        'pin': newPin.pin,
        'master_category': newPin.masterCategory,
        'is_active': true,
      }).select().maybeSingle();

      if (res != null) {
        final op = OperatorPinModel.fromMap(res);
        _localPins.removeWhere((p) => p.id == newPin.id || p.id == op.id || p.pin == op.pin);
        _localPins.add(op);
        _localPins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        await LocalCacheService.instance.savePins(_localPins);
        if (!_pinsStreamController.isClosed) {
          _pinsStreamController.add(List.unmodifiable(_localPins));
        }
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar novo PIN em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'create_operator_pin',
        'pin': newPin.toMap(),
      });
    }
  }

  /// Atualiza o nome, PIN ou setor de um funcionário localmente (0ms) e sincroniza com o Supabase
  Future<OperatorPinModel> updateOperatorPin({
    required String id,
    required String name,
    required String pin,
    required String masterCategory,
  }) async {
    final cleanName = name.trim();
    final cleanPin = pin.trim();
    if (cleanName.isEmpty) {
      throw Exception('O nome do funcionário não pode ser vazio.');
    }
    if (cleanPin.length != 4 || int.tryParse(cleanPin) == null) {
      throw Exception('O PIN deve conter exatamente 4 dígitos numéricos.');
    }

    final idx = _localPins.indexWhere((p) => p.id == id);
    if (idx == -1) {
      throw Exception('Funcionário/PIN não encontrado.');
    }

    final duplicatePin = _localPins.any((p) => p.id != id && p.pin == cleanPin);
    if (duplicatePin) {
      throw Exception('Este PIN já está em uso por outro funcionário.');
    }

    final updated = _localPins[idx].copyWith(
      name: cleanName,
      pin: cleanPin,
      masterCategory: masterCategory.toLowerCase().trim(),
    );

    _localPins[idx] = updated;
    _localPins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await LocalCacheService.instance.savePins(_localPins);
    if (!_pinsStreamController.isClosed) {
      _pinsStreamController.add(List.unmodifiable(_localPins));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return updated;
    }

    unawaited(_backgroundSyncUpdateOperatorPin(updated));
    return updated;
  }

  Future<void> _backgroundSyncUpdateOperatorPin(OperatorPinModel updated) async {
    if (_client == null || _isLocalMode) return;
    try {
      if (ProductModel.uuidRegex.hasMatch(updated.id)) {
        await _client!.from('operator_pins').update({
          'name': updated.name,
          'pin': updated.pin,
          'master_category': updated.masterCategory,
        }).eq('id', updated.id);
      } else {
        await _client!.from('operator_pins').upsert({
          'name': updated.name,
          'pin': updated.pin,
          'master_category': updated.masterCategory,
          'is_active': true,
        }, onConflict: 'pin');
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar atualização de PIN em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'update_operator_pin',
        'pin': updated.toMap(),
      });
    }
  }

  Future<void> moveProductMasterCategories({
    required String productId,
    required List<String> masterCategories,
  }) async {
    ProductModel? updatedProduct;
    final lIdx = _localProducts.indexWhere((p) => p.id == productId);
    if (lIdx != -1) {
      updatedProduct = _localProducts[lIdx].copyWith(
        masterCategories: masterCategories,
        updatedAt: DateTime.now(),
      );
      _localProducts[lIdx] = updatedProduct;
    }
    final aIdx = _allProducts.indexWhere((p) => p.id == productId);
    if (aIdx != -1) {
      updatedProduct = _allProducts[aIdx].copyWith(
        masterCategories: masterCategories,
        updatedAt: DateTime.now(),
      );
      _allProducts[aIdx] = updatedProduct;
    }

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    if (updatedProduct != null) {
      unawaited(_backgroundSyncUpdateProduct(updatedProduct));
    }
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
    final Map<String, List<String>> updatedMap = {};

    for (final id in productIds) {
      final pIdx = _allProducts.indexWhere((p) => p.id == id);
      final lIdx = _localProducts.indexWhere((p) => p.id == id);
      final baseProd = pIdx != -1 ? _allProducts[pIdx] : (lIdx != -1 ? _localProducts[lIdx] : null);
      List<String> current = baseProd != null ? List<String>.from(baseProd.masterCategories) : [];

      if (!current.contains(catId)) {
        current.add(catId);
      }
      if (catId != 'outros' && current.contains('outros')) {
        current.remove('outros');
      }

      ProductModel? updatedP;
      if (pIdx != -1) {
        updatedP = _allProducts[pIdx].copyWith(masterCategories: current);
        _allProducts[pIdx] = updatedP;
      }
      if (lIdx != -1) {
        updatedP = _localProducts[lIdx].copyWith(masterCategories: current);
        _localProducts[lIdx] = updatedP;
      }
      if (updatedP != null) {
        updatedMap[id] = List<String>.from(updatedP.toMap(forSupabase: true)['master_categories'] as List);
      } else {
        updatedMap[id] = current;
      }
    }

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    // Sincronização com Supabase em segundo plano
    unawaited(_backgroundSyncBulkMasterCategory(updatedMap, 'bulk_add_master_cat'));
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
    final Map<String, List<String>> updatedMap = {};

    for (final id in productIds) {
      final pIdx = _allProducts.indexWhere((p) => p.id == id);
      final lIdx = _localProducts.indexWhere((p) => p.id == id);
      final baseProd = pIdx != -1 ? _allProducts[pIdx] : (lIdx != -1 ? _localProducts[lIdx] : null);
      List<String> current = baseProd != null ? List<String>.from(baseProd.masterCategories) : [];

      current.remove(catId);
      if (current.isEmpty) {
        current.add('outros');
      }

      ProductModel? updatedP;
      if (pIdx != -1) {
        updatedP = _allProducts[pIdx].copyWith(masterCategories: current);
        _allProducts[pIdx] = updatedP;
      }
      if (lIdx != -1) {
        updatedP = _localProducts[lIdx].copyWith(masterCategories: current);
        _localProducts[lIdx] = updatedP;
      }
      if (updatedP != null) {
        updatedMap[id] = List<String>.from(updatedP.toMap(forSupabase: true)['master_categories'] as List);
      } else {
        updatedMap[id] = current;
      }
    }

    await LocalCacheService.instance.saveProducts(_allProducts.isNotEmpty ? _allProducts : _localProducts);
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_allProducts.isNotEmpty ? _allProducts : _localProducts));
    }

    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    // Sincronização com Supabase em segundo plano
    unawaited(_backgroundSyncBulkMasterCategory(updatedMap, 'bulk_remove_master_cat'));
  }

  Future<void> _backgroundSyncBulkMasterCategory(
    Map<String, List<String>> updatedMap,
    String actionType,
  ) async {
    if (_client == null || _isLocalMode) return;
    for (final entry in updatedMap.entries) {
      try {
        await _client!
            .from(AppConstants.tableProducts)
            .update({'master_categories': entry.value})
            .eq('id', entry.key);
      } catch (e) {
        debugPrint('Aviso: falha de rede ao sincronizar setor em lote no Supabase em segundo plano: $e');
        await LocalCacheService.instance.queueSyncAction({
          'action_type': actionType,
          'product_id': entry.key,
          'master_categories': entry.value,
        });
      }
    }
  }

  Future<void> deleteOperatorPin(String id) async {
    _localPins.removeWhere((p) => p.id == id);
    await LocalCacheService.instance.savePins(_localPins);
    if (!_pinsStreamController.isClosed) {
      _pinsStreamController.add(List.unmodifiable(_localPins));
    }
    if (_isLocalMode || _client == null) {
      _notifyLocal();
      return;
    }

    unawaited(_backgroundSyncDeleteOperatorPin(id));
  }

  Future<void> _backgroundSyncDeleteOperatorPin(String id) async {
    if (_client == null || _isLocalMode) return;
    try {
      if (ProductModel.uuidRegex.hasMatch(id)) {
        await _client!.from('operator_pins').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar exclusão de PIN em segundo plano: $e');
      await LocalCacheService.instance.queueSyncAction({
        'action_type': 'delete_operator_pin',
        'id': id,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // HISTÓRICO DE MOVIMENTAÇÕES (GRAVAÇÃO SEGURA & SINCRONIZAÇÃO HÍBRIDA)
  // ---------------------------------------------------------------------------

  Future<void> _recordMovement(StockMovementModel movement) async {
    // 1. Sempre atualiza a memória local imediatamente (resposta instantânea na UI 0ms)
    _localMovements.removeWhere((m) => m.id.isNotEmpty && m.id == movement.id);
    _localMovements.insert(0, movement);
    if (!_movementsStreamController.isClosed) {
      _movementsStreamController.add(List.unmodifiable(_localMovements));
    }

    // 2. Se conectado ao Supabase, grava no banco em segundo plano sem travar a interface
    if (!_isLocalMode && _client != null) {
      unawaited(_backgroundSyncMovement(movement));
    }
  }

  Future<void> _backgroundSyncMovement(StockMovementModel movement) async {
    if (_client == null || _isLocalMode) return;
    try {
      final payload = movement.toMap(forDatabaseInsert: true);
      final res = await _client!
          .from('stock_movements')
          .insert(payload)
          .select()
          .maybeSingle();

      if (res != null) {
        final serverMovement = StockMovementModel.fromMap(res);
        final idx = _localMovements.indexWhere((m) => m.id == movement.id);
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
      debugPrint('Aviso: falha ao gravar stock_movements no Supabase em segundo plano: $e');
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
          final idx = _localMovements.indexWhere((m) => m.id == movement.id);
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
        debugPrint('Falha no fallback de gravação de stock_movements em segundo plano: $e2');
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
