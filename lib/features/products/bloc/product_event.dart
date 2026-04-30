abstract class ProductEvent {}

class LoadProducts extends ProductEvent {}

class AddProduct extends ProductEvent {
  final String name;
  final double price;

  AddProduct({required this.name, required this.price});
}

class SeedProducts extends ProductEvent {}
