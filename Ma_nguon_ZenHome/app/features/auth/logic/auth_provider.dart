import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/features/auth/data/auth_repository.dart';
import 'package:zenhome_app/core/repositories/firestore_repository.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

@riverpod
FirestoreRepository firestoreRepository(FirestoreRepositoryRef ref) {
  return FirestoreRepository();
}

@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
Future<Map<String, dynamic>?> userData(UserDataRef ref, String email) {
  return ref.watch(firestoreRepositoryProvider).getUserData(email);
}
