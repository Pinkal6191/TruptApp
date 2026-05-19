import 'package:equatable/equatable.dart';
import '../../../core/models/customer_model.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object> get props => [];
}

class LoadCustomers extends CustomerEvent {}

class AddCustomer extends CustomerEvent {
  final CustomerModel customer;
  const AddCustomer(this.customer);

  @override
  List<Object> get props => [customer];
}

class UpdateCustomerMetrics extends CustomerEvent {
  final String customerId;
  final double orderAmount;
  const UpdateCustomerMetrics(this.customerId, this.orderAmount);

  @override
  List<Object> get props => [customerId, orderAmount];
}
