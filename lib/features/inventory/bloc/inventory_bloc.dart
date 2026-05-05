import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/inventory_model.dart';
import '../repository/inventory_repository.dart';

// Events
abstract class InventoryEvent {}

class LoadInventory extends InventoryEvent {
  final String userId;
  LoadInventory(this.userId);
}

class WatchInventory extends InventoryEvent {
  final String userId;
  WatchInventory(this.userId);
}

class InventoryUpdated extends InventoryEvent {
  final List<InventoryModel> inventory;
  InventoryUpdated(this.inventory);
}

// States
abstract class InventoryState {}

class InventoryInitial extends InventoryState {}
class InventoryLoading extends InventoryState {}
class InventoryLoaded extends InventoryState {
  final List<InventoryModel> inventory;
  InventoryLoaded(this.inventory);
}
class InventoryError extends InventoryState {
  final String message;
  InventoryError(this.message);
}

// Bloc
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _inventoryRepository;
  StreamSubscription? _inventorySubscription;

  InventoryBloc({required InventoryRepository inventoryRepository})
      : _inventoryRepository = inventoryRepository,
        super(InventoryInitial()) {
    on<LoadInventory>(_onLoadInventory);
    on<WatchInventory>(_onWatchInventory);
    on<InventoryUpdated>(_onInventoryUpdated);
  }

  Future<void> _onLoadInventory(LoadInventory event, Emitter<InventoryState> emit) async {
    emit(InventoryLoading());
    try {
      final inventory = await _inventoryRepository.getUserInventory(event.userId);
      emit(InventoryLoaded(inventory));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  void _onWatchInventory(WatchInventory event, Emitter<InventoryState> emit) {
    emit(InventoryLoading());
    _inventorySubscription?.cancel();
    _inventorySubscription = _inventoryRepository.watchUserInventory(event.userId).listen(
      (inventory) => add(InventoryUpdated(inventory)),
      onError: (error) => emit(InventoryError(error.toString())),
    );
  }

  void _onInventoryUpdated(InventoryUpdated event, Emitter<InventoryState> emit) {
    emit(InventoryLoaded(event.inventory));
  }

  @override
  Future<void> close() {
    _inventorySubscription?.cancel();
    return super.close();
  }
}
