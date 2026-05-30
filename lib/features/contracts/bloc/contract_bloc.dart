import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contract_event.dart';
import 'contract_state.dart';
import '../../../core/models/contract_model.dart';

class ContractBloc extends Bloc<ContractEvent, ContractState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ContractBloc() : super(ContractInitial()) {
    on<LoadContracts>(_onLoadContracts);
    on<AddContract>(_onAddContract);
    on<UpdateContract>(_onUpdateContract);
    on<DeleteContract>(_onDeleteContract);
  }

  Future<void> _onLoadContracts(LoadContracts event, Emitter<ContractState> emit) async {
    emit(ContractLoading());
    try {
      final snapshot = await _firestore.collection('contracts').orderBy('createdAt', descending: true).get();
      final contracts = snapshot.docs.map((doc) {
        return ContractModel.fromMap(doc.data(), doc.id);
      }).toList();
      emit(ContractsLoaded(contracts));
    } catch (e) {
      emit(ContractError('Failed to load contracts: $e'));
    }
  }

  Future<void> _onAddContract(AddContract event, Emitter<ContractState> emit) async {
    try {
      final docRef = _firestore.collection('contracts').doc();
      final newContract = event.contract.copyWith(id: docRef.id);
      await docRef.set(newContract.toMap());
      add(LoadContracts());
      emit(const ContractOperationSuccess('Contract saved successfully.'));
    } catch (e) {
      emit(ContractError('Failed to save contract: $e'));
    }
  }

  Future<void> _onUpdateContract(UpdateContract event, Emitter<ContractState> emit) async {
    try {
      await _firestore.collection('contracts').doc(event.contract.id).update(event.contract.toMap());
      add(LoadContracts());
      emit(const ContractOperationSuccess('Contract updated successfully.'));
    } catch (e) {
      emit(ContractError('Failed to update contract: $e'));
    }
  }

  Future<void> _onDeleteContract(DeleteContract event, Emitter<ContractState> emit) async {
    try {
      await _firestore.collection('contracts').doc(event.contractId).delete();
      add(LoadContracts());
      emit(const ContractOperationSuccess('Contract deleted successfully.'));
    } catch (e) {
      emit(ContractError('Failed to delete contract: $e'));
    }
  }
}
