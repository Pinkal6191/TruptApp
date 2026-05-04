import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../core/models/user_model.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginEvent>(_onLoginEvent);
    on<SignupEvent>(_onSignupEvent);
    on<ForgotPasswordEvent>(_onForgotPasswordEvent);
    on<LogoutEvent>(_onLogoutEvent);
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);
          if (userModel.role != 'admin' && !userModel.isApproved) {
            emit(AuthApprovalPending());
          } else {
            emit(Authenticated(userModel));
          }
        } else {
          await _firebaseAuth.signOut();
          emit(Unauthenticated());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoginEvent(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (userDoc.exists) {
        final userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);
        if (userModel.role != 'admin' && !userModel.isApproved) {
          emit(AuthApprovalPending());
        } else {
          emit(Authenticated(userModel));
        }
      } else {
        await _firebaseAuth.signOut();
        emit(const AuthError('User record not found in database. Please contact admin.'));
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Authentication failed'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignupEvent(SignupEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      final userModel = UserModel(
        uid: userCredential.user!.uid,
        name: event.name,
        mobile: event.mobile,
        role: event.role,
        isApproved: false, // Explicitly false
      );

      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());

      emit(AuthApprovalPending());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Signup failed'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onForgotPasswordEvent(ForgotPasswordEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: event.email);
      emit(PasswordResetEmailSent());
      emit(Unauthenticated()); // Go back to login state
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Failed to send reset email'));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onLogoutEvent(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _firebaseAuth.signOut();
    emit(Unauthenticated());
  }
}
