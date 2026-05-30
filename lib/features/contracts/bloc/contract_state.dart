import 'package:equatable/equatable.dart';
import '../../../core/models/contract_model.dart';

abstract class ContractState extends Equatable {
  const ContractState();

  @override
  List<Object> get props => [];
}

class ContractInitial extends ContractState {}

class ContractLoading extends ContractState {}

class ContractsLoaded extends ContractState {
  final List<ContractModel> contracts;

  const ContractsLoaded(this.contracts);

  @override
  List<Object> get props => [contracts];
}

class ContractError extends ContractState {
  final String message;

  const ContractError(this.message);

  @override
  List<Object> get props => [message];
}

class ContractOperationSuccess extends ContractState {
  final String message;

  const ContractOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}
