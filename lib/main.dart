import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/approval_pending_screen.dart';
import 'features/admin/presentation/admin_dashboard.dart';
import 'features/partner/presentation/partner_dashboard.dart';
import 'features/distributor/presentation/distributor_dashboard.dart';
import 'features/products/bloc/product_bloc.dart';
import 'features/products/repository/product_repository.dart';
import 'features/orders/bloc/order_bloc.dart';
import 'features/orders/repository/order_repository.dart';
import 'features/expenses/bloc/expense_bloc.dart';
import 'features/expenses/repository/expense_repository.dart';
import 'features/inventory/bloc/inventory_bloc.dart';
import 'features/inventory/repository/inventory_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc()..add(CheckAuthStatus()),
        ),
        BlocProvider(
          create: (context) => ProductBloc(productRepository: ProductRepository()),
        ),
        BlocProvider(
          create: (context) => OrderBloc(orderRepository: OrderRepository()),
        ),
        BlocProvider(
          create: (context) => ExpenseBloc(expenseRepository: ExpenseRepository()),
        ),
        BlocProvider(
          create: (context) => InventoryBloc(inventoryRepository: InventoryRepository()),
        ),
      ],
      child: MaterialApp(
        title: 'Trupt Enterprise',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (state is AuthApprovalPending) {
          return const ApprovalPendingScreen();
        } else if (state is Authenticated) {
          // Route based on role
          if (state.user.role == 'admin') {
            return const AdminDashboard();
          } else if (state.user.role == 'distributor') {
            return const DistributorDashboard();
          } else {
            return const PartnerDashboard();
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
