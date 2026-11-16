import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  final bool isWithdrawal; // true = Retirada (pegar), false = Entrada (repor)

  CartItemModel({
    required this.product,
    required this.quantity,
    this.isWithdrawal = true,
  });

  int get delta => isWithdrawal ? -quantity : quantity;
}
