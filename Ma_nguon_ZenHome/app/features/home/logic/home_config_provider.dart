import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zenhome_app/core/models/smart_config.dart';

final homeConfigProvider = ChangeNotifierProvider<HomeConfigNotifier>((ref) {
  return HomeConfigNotifier();
});

class HomeConfigNotifier extends ChangeNotifier {
  SmartConfig _activeConfig = SmartConfig(
    userId: 'guest',
    macAddress: 'unknown_mac',
    devices: [],
  );
  List<SmartConfig> _availableHomes = [];
  
  final _secureStorage = const FlutterSecureStorage();

  SmartConfig get activeConfig => _activeConfig;
  List<SmartConfig> get availableHomes => _availableHomes;

  Future<void> loadConfigFromStorage() async {
    String? homesJson = await _secureStorage.read(key: 'available_homes');
    String? activeId = await _secureStorage.read(key: 'active_home_id');
    
    // Migration fallback from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (homesJson == null) {
      homesJson = prefs.getString('available_homes');
      if (homesJson != null) {
        await _secureStorage.write(key: 'available_homes', value: homesJson);
        await prefs.remove('available_homes');
      }
    }
    
    if (activeId == null) {
      activeId = prefs.getString('active_home_id');
      if (activeId != null) {
        await _secureStorage.write(key: 'active_home_id', value: activeId);
        await prefs.remove('active_home_id');
      }
    }

    if (homesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(homesJson);
        _availableHomes = decoded.map((e) => SmartConfig.fromJson(e)).toList();
      } catch (e) {
        _availableHomes = [];
      }
    }

    if (activeId != null && _availableHomes.isNotEmpty) {
      try {
        _activeConfig = _availableHomes.firstWhere((h) => h.userId == activeId);
      } catch (e) {
        _activeConfig = _availableHomes.first;
      }
    } else if (_availableHomes.isNotEmpty) {
      _activeConfig = _availableHomes.first;
    }
    notifyListeners();
  }

  Future<void> saveConfigToStorage(SmartConfig newConfig) async {
    _activeConfig = newConfig;
    
    int index = _availableHomes.indexWhere((h) => h.userId == newConfig.userId);
    if (index != -1) {
      _availableHomes[index] = newConfig;
    } else {
      _availableHomes.add(newConfig);
    }

    await _secureStorage.write(key: 'active_home_id', value: _activeConfig.userId);
    await _secureStorage.write(key: 'available_homes', value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> switchActiveHome(String userId) async {
    int index = _availableHomes.indexWhere((h) => h.userId == userId);
    if (index != -1) {
      _activeConfig = _availableHomes[index];
      try {
        await _secureStorage.write(key: 'active_home_id', value: _activeConfig.userId).timeout(const Duration(seconds: 2));
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_home_id', _activeConfig.userId);
      }
      notifyListeners();
    }
  }

  Future<void> setAvailableHomes(List<SmartConfig> homes) async {
    _availableHomes = homes;
    if (_availableHomes.isNotEmpty) {
      bool hasActive = _availableHomes.any((h) => h.userId == _activeConfig.userId);
      if (!hasActive) _activeConfig = _availableHomes.first;
    } else {
      _activeConfig = SmartConfig(userId: 'guest', macAddress: 'unknown_mac', devices: []);
    }
    
    await _secureStorage.write(key: 'active_home_id', value: _activeConfig.userId);
    await _secureStorage.write(key: 'available_homes', value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearAllHomes() async {
    _availableHomes = [];
    _activeConfig = SmartConfig(
      userId: 'guest',
      macAddress: 'unknown_mac',
      devices: [],
    );
    await _secureStorage.delete(key: 'active_home_id');
    await _secureStorage.delete(key: 'available_homes');
    notifyListeners();
  }

  /// Gọi hàm này sau khi bạn đã thay đổi trực tiếp (mutate) thuộc tính của activeConfig (ví dụ: đổi tên thiết bị)
  void notifyChanges() {
    notifyListeners();
  }
}
