import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/product_repository.dart';
import 'product_event.dart';
import 'product_state.dart';
import '../../../core/models/product_model.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;

  ProductBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<SeedProducts>(_onSeedProducts);
  }

  Future<void> _onLoadProducts(LoadProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      final List<ProductModel> products = await _productRepository.getProducts();
      emit(ProductLoaded(products: products));
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onAddProduct(AddProduct event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      final product = ProductModel(
        id: '', // Firestore auto-generates ID on add
        name: event.name,
        defaultPrice: event.price,
      );
      await _productRepository.addProduct(product);
      emit(ProductOperationSuccess(message: 'Product added successfully'));
      add(LoadProducts());
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }

  Future<void> _onSeedProducts(SeedProducts event, Emitter<ProductState> emit) async {
    emit(ProductLoading());
    try {
      await _productRepository.seedInitialProducts();
      add(LoadProducts());
    } catch (e) {
      emit(ProductError(message: e.toString()));
    }
  }
}
