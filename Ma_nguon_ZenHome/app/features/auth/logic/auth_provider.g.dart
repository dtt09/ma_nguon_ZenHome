// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRepositoryHash() => r'e3b22fd7863ea1be0b322870da43112c60f80087';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$firestoreRepositoryHash() =>
    r'45c65537541eefc706c23ff0a12950848ecdffb5';

/// See also [firestoreRepository].
@ProviderFor(firestoreRepository)
final firestoreRepositoryProvider =
    AutoDisposeProvider<FirestoreRepository>.internal(
      firestoreRepository,
      name: r'firestoreRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$firestoreRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreRepositoryRef = AutoDisposeProviderRef<FirestoreRepository>;
String _$authStateHash() => r'132c5c557707d07a9765c35ab6e56b9b31e15981';

/// See also [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<User?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateRef = AutoDisposeStreamProviderRef<User?>;
String _$userDataHash() => r'03a604387ea7a4a26bfe66fc56623c4bc8788ab9';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [userData].
@ProviderFor(userData)
const userDataProvider = UserDataFamily();

/// See also [userData].
class UserDataFamily extends Family<AsyncValue<Map<String, dynamic>?>> {
  /// See also [userData].
  const UserDataFamily();

  /// See also [userData].
  UserDataProvider call(String email) {
    return UserDataProvider(email);
  }

  @override
  UserDataProvider getProviderOverride(covariant UserDataProvider provider) {
    return call(provider.email);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userDataProvider';
}

/// See also [userData].
class UserDataProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>?> {
  /// See also [userData].
  UserDataProvider(String email)
    : this._internal(
        (ref) => userData(ref as UserDataRef, email),
        from: userDataProvider,
        name: r'userDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userDataHash,
        dependencies: UserDataFamily._dependencies,
        allTransitiveDependencies: UserDataFamily._allTransitiveDependencies,
        email: email,
      );

  UserDataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.email,
  }) : super.internal();

  final String email;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>?> Function(UserDataRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserDataProvider._internal(
        (ref) => create(ref as UserDataRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        email: email,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>?> createElement() {
    return _UserDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserDataProvider && other.email == email;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, email.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserDataRef on AutoDisposeFutureProviderRef<Map<String, dynamic>?> {
  /// The parameter `email` of this provider.
  String get email;
}

class _UserDataProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>?>
    with UserDataRef {
  _UserDataProviderElement(super.provider);

  @override
  String get email => (origin as UserDataProvider).email;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
