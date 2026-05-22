import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/expense_repository.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _expenseRepository;

  ExpenseBloc({required ExpenseRepository expenseRepository})
      : _expenseRepository = expenseRepository,
        super(ExpenseInitial()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<AddExpense>(_onAddExpense);
    on<UpdateExpense>(_onUpdateExpense);
    on<DeleteExpense>(_onDeleteExpense);
    on<ResetExpenseState>((event, emit) => emit(ExpenseInitial()));
  }

  Future<void> _onLoadExpenses(LoadExpenses event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      final expenses = await _expenseRepository.getExpenses();
      emit(ExpensesLoaded(expenses: expenses));
    } catch (e) {
      emit(ExpenseError(message: e.toString()));
    }
  }

  Future<void> _onAddExpense(AddExpense event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.addExpense(event.expense);
      emit(ExpenseOperationSuccess(message: 'Expense added successfully!'));
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(message: e.toString()));
    }
  }

  Future<void> _onUpdateExpense(UpdateExpense event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.updateExpense(event.expense);
      emit(ExpenseOperationSuccess(message: 'Expense updated successfully!'));
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(message: e.toString()));
    }
  }

  Future<void> _onDeleteExpense(DeleteExpense event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      await _expenseRepository.deleteExpense(event.id);
      emit(ExpenseOperationSuccess(message: 'Expense deleted successfully!'));
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(message: e.toString()));
    }
  }
}
