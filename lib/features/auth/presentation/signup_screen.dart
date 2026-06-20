import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'partner';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1329), // Ultra Dark Navy
              Color(0xFF1E3A8A), // Royal Blue
              Color(0xFF0F172A), // Slate 900
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48), // Padding to account for back button
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'HAR BOOND MEIN TRUPTI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Join Trupt Enterprise as a Partner, Distributor, or CA/Accountant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 32),
                      BlocListener<AuthBloc, AuthState>(
                        listener: (context, state) {
                          if (state is AuthError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: Colors.red.shade800,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                          if (state is AuthApprovalPending || state is Authenticated) {
                            // Success! Pop back to AuthWrapper which will show the correct dashboard/pending screen
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                                        prefixIcon: Icon(Icons.person_outline, color: Colors.white.withValues(alpha: 0.6)),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.02),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Please enter your name' : null,
                                    ),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                      controller: _mobileController,
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      decoration: InputDecoration(
                                        labelText: 'Mobile Number',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.white.withValues(alpha: 0.6)),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.02),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your mobile number';
                                        }
                                        final mobileRegex = RegExp(r'^[0-9]{10}$');
                                        if (!mobileRegex.hasMatch(value.trim())) {
                                          return 'Please enter a valid 10-digit mobile number';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                      controller: _emailController,
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      decoration: InputDecoration(
                                        labelText: 'Email Address',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                                        prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withValues(alpha: 0.6)),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.02),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your email address';
                                        }
                                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                        if (!emailRegex.hasMatch(value.trim())) {
                                          return 'Please enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                      controller: _passwordController,
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                                        prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.6)),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            color: Colors.white.withValues(alpha: 0.6),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.02),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a password';
                                        }
                                        if (value.length < 6) {
                                          return 'Password must be at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Register as:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedRole = 'partner'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _selectedRole == 'partner'
                                                    ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _selectedRole == 'partner'
                                                      ? const Color(0xFF38BDF8)
                                                      : Colors.white.withValues(alpha: 0.08),
                                                  width: _selectedRole == 'partner' ? 2.0 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.handshake_outlined,
                                                    color: _selectedRole == 'partner'
                                                        ? const Color(0xFF38BDF8)
                                                        : Colors.white.withValues(alpha: 0.6),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Partner',
                                                    style: TextStyle(
                                                      color: _selectedRole == 'partner'
                                                          ? Colors.white
                                                          : Colors.white.withValues(alpha: 0.6),
                                                      fontWeight: _selectedRole == 'partner'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedRole = 'distributor'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _selectedRole == 'distributor'
                                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _selectedRole == 'distributor'
                                                      ? const Color(0xFF3B82F6)
                                                      : Colors.white.withValues(alpha: 0.08),
                                                  width: _selectedRole == 'distributor' ? 2.0 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.local_shipping_outlined,
                                                    color: _selectedRole == 'distributor'
                                                        ? const Color(0xFF3B82F6)
                                                        : Colors.white.withValues(alpha: 0.6),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Distributor',
                                                    style: TextStyle(
                                                      color: _selectedRole == 'distributor'
                                                          ? Colors.white
                                                          : Colors.white.withValues(alpha: 0.6),
                                                      fontWeight: _selectedRole == 'distributor'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selectedRole = 'accountant'),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _selectedRole == 'accountant'
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _selectedRole == 'accountant'
                                                      ? const Color(0xFF10B981)
                                                      : Colors.white.withValues(alpha: 0.08),
                                                  width: _selectedRole == 'accountant' ? 2.0 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.account_balance_outlined,
                                                    color: _selectedRole == 'accountant'
                                                        ? const Color(0xFF10B981)
                                                        : Colors.white.withValues(alpha: 0.6),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Accountant',
                                                    style: TextStyle(
                                                      color: _selectedRole == 'accountant'
                                                          ? Colors.white
                                                          : Colors.white.withValues(alpha: 0.6),
                                                      fontWeight: _selectedRole == 'accountant'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Container(
                                      width: double.infinity,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF38BDF8), Color(0xFF3B82F6), Color(0xFF6366F1)],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: BlocBuilder<AuthBloc, AuthState>(
                                        builder: (context, state) {
                                          return ElevatedButton(
                                            onPressed: state is AuthLoading
                                                ? null
                                                : () {
                                                    if (_formKey.currentState?.validate() ?? false) {
                                                      context.read<AuthBloc>().add(
                                                            SignupEvent(
                                                              name: _nameController.text.trim(),
                                                              mobile: _mobileController.text.trim(),
                                                              email: _emailController.text.trim(),
                                                              password: _passwordController.text.trim(),
                                                              role: _selectedRole,
                                                            ),
                                                          );
                                                    }
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: state is AuthLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Register Now',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account?",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Custom top-left back button
              Positioned(
                top: 8,
                left: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
