import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalPieces =>
      _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  void addItem({
    required ProductModel product,
    required int quantity,
    required bool isWithdrawal,
  }) {
    if (quantity <= 0) return;

    final index = _items.indexWhere((item) =>
        item.product.id == product.id && item.isWithdrawal == isWithdrawal);

    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItemModel(
        product: product,
        quantity: quantity,
        isWithdrawal: isWithdrawal,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _items.length) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = newQuantity;
      }
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
