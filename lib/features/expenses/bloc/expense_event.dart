import '../../../core/models/expense_model.dart';

abstract class ExpenseEvent {}

class LoadExpenses extends ExpenseEvent {}

class AddExpense extends ExpenseEvent {
  final ExpenseModel expense;
  AddExpense({required this.expense});
}

class ResetExpenseState extends ExpenseEvent {}

class UpdateExpense extends ExpenseEvent {
  final ExpenseModel expense;
  UpdateExpense({required this.expense});
}

class DeleteExpense extends ExpenseEvent {
  final String id;
  DeleteExpense({required this.id});
}
