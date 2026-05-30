import 'package:equatable/equatable.dart';
import '../../../core/models/contract_model.dart';

abstract class ContractEvent extends Equatable {
  const ContractEvent();

  @override
  List<Object> get props => [];
}

class LoadContracts extends ContractEvent {}

class AddContract extends ContractEvent {
  final ContractModel contract;

  const AddContract(this.contract);

  @override
  List<Object> get props => [contract];
}

class UpdateContract extends ContractEvent {
  final ContractModel contract;

  const UpdateContract(this.contract);

  @override
  List<Object> get props => [contract];
}

class DeleteContract extends ContractEvent {
  final String contractId;

  const DeleteContract(this.contractId);

  @override
  List<Object> get props => [contractId];
}
