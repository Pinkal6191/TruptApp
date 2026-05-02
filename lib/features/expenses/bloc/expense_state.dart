import '../../../core/models/expense_model.dart';

abstract class ExpenseState {}

class ExpenseInitial extends ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpensesLoaded extends ExpenseState {
  final List<ExpenseModel> expenses;
  ExpensesLoaded({required this.expenses});
}

class ExpenseOperationSuccess extends ExpenseState {
  final String message;
  ExpenseOperationSuccess({required this.message});
}

class ExpenseError extends ExpenseState {
  final String message;
  ExpenseError({required this.message});
}
