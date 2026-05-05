import '../../../core/models/product_model.dart';

abstract class ProductEvent {}

class LoadProducts extends ProductEvent {}
class ResetProductState extends ProductEvent {}

class AddProduct extends ProductEvent {
  final ProductModel product;
  AddProduct(this.product);
}

class UpdateProduct extends ProductEvent {
  final ProductModel product;
  UpdateProduct(this.product);
}

class DeleteProduct extends ProductEvent {
  final String productId;
  DeleteProduct(this.productId);
}

class SeedProducts extends ProductEvent {}
