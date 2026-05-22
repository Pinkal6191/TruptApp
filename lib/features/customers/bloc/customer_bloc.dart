import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository _repository;

  CustomerBloc({required CustomerRepository repository})
      : _repository = repository,
        super(CustomerInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomerMetrics>(_onUpdateCustomerMetrics);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomerState> emit) async {
    emit(CustomerLoading());
    try {
      final customers = await _repository.getAllCustomers();
      emit(CustomersLoaded(customers));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<CustomerState> emit) async {
    try {
      await _repository.saveCustomer(event.customer);
      // Reload customers after adding
      add(LoadCustomers());
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onUpdateCustomerMetrics(UpdateCustomerMetrics event, Emitter<CustomerState> emit) async {
    try {
      await _repository.updateCustomerMetrics(event.customerId, event.orderAmount, ordersDelta: event.ordersDelta);
      // Reload customers after updating
      add(LoadCustomers());
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onUpdateCustomer(UpdateCustomer event, Emitter<CustomerState> emit) async {
    try {
      await _repository.updateCustomer(event.customer);
      add(LoadCustomers());
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> _onDeleteCustomer(DeleteCustomer event, Emitter<CustomerState> emit) async {
    try {
      await _repository.deleteCustomer(event.customerId);
      add(LoadCustomers());
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }
}
