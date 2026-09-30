// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mqtt_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mqttRepositoryHash() => r'86e92a8719affb8d82f5148ad4fd70691696e3e2';

/// See also [mqttRepository].
@ProviderFor(mqttRepository)
final mqttRepositoryProvider = Provider<MqttRepository>.internal(
  mqttRepository,
  name: r'mqttRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mqttRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MqttRepositoryRef = ProviderRef<MqttRepository>;
String _$mqttConnectionStateHash() =>
    r'9d18bdf7bca1db01ae52fb6e252719f1ae0f1909';

/// See also [MqttConnectionState].
@ProviderFor(MqttConnectionState)
final mqttConnectionStateProvider =
    NotifierProvider<MqttConnectionState, int>.internal(
      MqttConnectionState.new,
      name: r'mqttConnectionStateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mqttConnectionStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MqttConnectionState = Notifier<int>;
String _$espOnlineStateHash() => r'022a0b938a51851f22126c70d4216750ba178a11';

/// See also [EspOnlineState].
@ProviderFor(EspOnlineState)
final espOnlineStateProvider = NotifierProvider<EspOnlineState, bool>.internal(
  EspOnlineState.new,
  name: r'espOnlineStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$espOnlineStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EspOnlineState = Notifier<bool>;
String _$globalDeviceStatesHash() =>
    r'2fa80f39ccf532f48eb9fd4496b95da354c89b30';

/// See also [GlobalDeviceStates].
@ProviderFor(GlobalDeviceStates)
final globalDeviceStatesProvider =
    NotifierProvider<GlobalDeviceStates, Map<String, bool>>.internal(
      GlobalDeviceStates.new,
      name: r'globalDeviceStatesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$globalDeviceStatesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GlobalDeviceStates = Notifier<Map<String, bool>>;
String _$mqttIndoorTempHash() => r'd2000874f85748270c1ddf4b527f9b154f0e7d76';

/// See also [MqttIndoorTemp].
@ProviderFor(MqttIndoorTemp)
final mqttIndoorTempProvider =
    AutoDisposeNotifierProvider<MqttIndoorTemp, String>.internal(
      MqttIndoorTemp.new,
      name: r'mqttIndoorTempProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mqttIndoorTempHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MqttIndoorTemp = AutoDisposeNotifier<String>;
String _$mqttNotificationHash() => r'82aa93ecb3a672c39ff4227f663f44c996574e32';

/// See also [MqttNotification].
@ProviderFor(MqttNotification)
final mqttNotificationProvider =
    NotifierProvider<MqttNotification, String>.internal(
      MqttNotification.new,
      name: r'mqttNotificationProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mqttNotificationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MqttNotification = Notifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
