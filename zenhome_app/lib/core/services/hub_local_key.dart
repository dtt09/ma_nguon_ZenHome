import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HubLocalKey {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String generate() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String _id(String home, String mac) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || home.isEmpty) throw StateError('Missing hub owner');
    return 'hub-v2/${Uri.encodeComponent(uid)}/${Uri.encodeComponent(home)}/${mac.replaceAll(RegExp('[:-]'), '').toUpperCase()}';
  }

  static Future<String?> read(String home, String mac) => _storage.read(key: _id(home, mac));
  static Future<void> save(String home, String mac, String key) => _storage.write(key: _id(home, mac), value: key);
}
