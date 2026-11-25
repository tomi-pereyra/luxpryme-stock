import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/category_model.dart';
import '../models/master_category_model.dart';
import '../models/operator_pin_model.dart';
import '../models/product_model.dart';
import '../models/stock_conflict_model.dart';
import '../models/stock_movement_model.dart';

class LocalCacheService {
  static final LocalCacheService instance = LocalCacheService._();
  LocalCacheService._();

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;

    try {
      if (!kIsWeb) {
        final docsDir = await getApplicationDocumentsDirectory();
        final dir = Directory('${docsDir.path}/luxpryme_offline_cache');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        _cacheDir = dir;
        return _cacheDir!;
      }
    } catch (e) {
      debugPrint('Aviso: path_provider indisponível, usando fallback de diretório local: $e');
    }

    final fallback = Directory('.luxpryme_cache');
    if (!fallback.existsSync()) {
      fallback.createSync(recursive: true);
    }
    _cacheDir = fallback;
    return _cacheDir!;
  }

  File _getFile(Directory dir, String filename) {
    return File('${dir.path}/$filename');
  }

  // ---------------------------------------------------------------------------
  // PRODUTOS
  // ---------------------------------------------------------------------------

  Future<void> saveProducts(List<ProductModel> products) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_products.json');
      final list = products.map((p) => p.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache local de produtos: $e');
    }
  }

  Future<List<ProductModel>?> loadProducts() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_products.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => ProductModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache local de produtos: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CATEGORIAS COMUNS
  // ---------------------------------------------------------------------------

  Future<void> saveCategories(List<CategoryModel> categories) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_categories.json');
      final list = categories.map((c) => c.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache de categorias: $e');
    }
  }

  Future<List<CategoryModel>?> loadCategories() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_categories.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => CategoryModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache de categorias: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CATEGORIAS MESTRES
  // ---------------------------------------------------------------------------

  Future<void> saveMasterCategories(List<MasterCategoryModel> masterCats) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_master_categories.json');
      final list = masterCats.map((mc) => mc.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache de categorias mestres: $e');
    }
  }

  Future<List<MasterCategoryModel>?> loadMasterCategories() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_master_categories.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => MasterCategoryModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache de categorias mestres: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PINS DE OPERADORES
  // ---------------------------------------------------------------------------

  Future<void> savePins(List<OperatorPinModel> pins) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_pins.json');
      final list = pins.map((p) => p.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache de pins: $e');
    }
  }

  Future<List<OperatorPinModel>?> loadPins() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_pins.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => OperatorPinModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache de pins: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HISTÓRICO DE MOVIMENTAÇÕES
  // ---------------------------------------------------------------------------

  Future<void> saveMovements(List<StockMovementModel> movements) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_movements.json');
      final list = movements.map((m) => m.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache de movimentações: $e');
    }
  }

  Future<List<StockMovementModel>?> loadMovements() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_movements.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => StockMovementModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache de movimentações: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // LIXEIRA DE PRODUTOS EXCLUÍDOS (TRASH BIN)
  // ---------------------------------------------------------------------------

  Future<void> saveTrash(List<ProductModel> trash) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_trash.json');
      final list = trash.map((p) => p.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar cache de lixeira: $e');
    }
  }

  Future<List<ProductModel>?> loadTrash() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'cached_trash.json');
      if (!await file.exists()) return null;

      final str = await file.readAsString();
      if (str.trim().isEmpty) return null;

      final List list = jsonDecode(str);
      return list
          .map((item) => ProductModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar cache de lixeira: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // FILA DE SINCRONIZAÇÃO OFFLINE (PENDING SYNC QUEUE)
  // ---------------------------------------------------------------------------

  Future<void> queueSyncAction(Map<String, dynamic> action) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'pending_sync_queue.json');
      List<dynamic> list = [];
      if (await file.exists()) {
        final str = await file.readAsString();
        if (str.trim().isNotEmpty) {
          list = jsonDecode(str);
        }
      }
      list.add({
        ...action,
        '_queued_at': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao enfileirar ação de sincronização offline: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadPendingSyncActions() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'pending_sync_queue.json');
      if (!await file.exists()) return [];

      final str = await file.readAsString();
      if (str.trim().isEmpty) return [];

      final List list = jsonDecode(str);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Erro ao ler fila de sincronização pendente: $e');
      return [];
    }
  }

  Future<void> savePendingSyncActions(List<Map<String, dynamic>> actions) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'pending_sync_queue.json');
      await file.writeAsString(jsonEncode(actions));
    } catch (e) {
      debugPrint('Erro ao atualizar fila de sincronização: $e');
    }
  }

  Future<void> clearPendingSyncActions() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'pending_sync_queue.json');
      if (await file.exists()) {
        await file.writeAsString(jsonEncode([]));
      }
    } catch (e) {
      debugPrint('Erro ao limpar fila de sincronização: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CONFLITOS DE ESTOQUE (SALDO NEGATIVO / DIVERGÊNCIAS DETECTADAS)
  // ---------------------------------------------------------------------------

  Future<void> saveConflicts(List<StockConflictModel> conflicts) async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'stock_conflicts.json');
      final list = conflicts.map((c) => c.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar conflitos de estoque: $e');
    }
  }

  Future<List<StockConflictModel>> loadConflicts() async {
    try {
      final dir = await _getCacheDirectory();
      final file = _getFile(dir, 'stock_conflicts.json');
      if (!await file.exists()) return [];

      final str = await file.readAsString();
      if (str.trim().isEmpty) return [];

      final List list = jsonDecode(str);
      return list
          .map((e) => StockConflictModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar conflitos de estoque: $e');
      return [];
    }
  }
}
