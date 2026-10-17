import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Đồng bộ trực tiếp 100% dữ liệu tài khoản, thiết bị và nhà từ Cloud Firestore
  Future<bool> syncFromFirestore({String? targetUsername}) async {
    try {
      String? username = targetUsername;
      if (username == null || username.isEmpty) {
        if (_activeConfig.userId != 'guest' && _activeConfig.userId.isNotEmpty) {
          username = _activeConfig.ownerEmail ?? _activeConfig.userId;
        }
      }
      if (username == null || username.isEmpty || username == 'guest') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final q = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: currentUser.uid).limit(1).get();
          if (q.docs.isNotEmpty) {
            username = q.docs.first.id;
          }
        }
      }
      if (username == null || username.isEmpty || username == 'guest') return false;

      final myDoc = await FirebaseFirestore.instance.collection('users').doc(username).get();
      if (!myDoc.exists) return false;
      final data = myDoc.data() as Map<String, dynamic>;

      List<DeviceConfig> restoredDevices = [];
      if (data['devices'] != null) {
        restoredDevices = (data['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
      }

      List<SmartConfig> updatedHomes = [];
      final existingHomes = List<SmartConfig>.from(_availableHomes);
      int ownIdx = existingHomes.indexWhere((h) => h.userId == username);
      String homeName = (ownIdx != -1) ? existingHomes[ownIdx].homeName : 'Nhà của tôi';

      SmartConfig ownHome = SmartConfig(
        userId: username,
        macAddress: data['macAddress'] ?? 'unknown_mac',
        mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
        mqttUser: data['mqttUser'],
        mqttPass: data['mqttPass'],
        devices: restoredDevices,
        role: 'owner',
        homeName: homeName,
        ownerEmail: username,
        canEditAutomation: true,
      );
      updatedHomes.add(ownHome);

      if (data['ownerUsername'] != null && data['ownerUsername'].toString().isNotEmpty) {
        String ownerUsername = data['ownerUsername'];
        try {
          final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUsername).get();
          if (ownerDoc.exists) {
            final ownerData = ownerDoc.data() as Map<String, dynamic>;
            List<DeviceConfig> ownerDevices = [];
            if (ownerData['devices'] != null) {
              ownerDevices = (ownerData['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
            }
            String ownerName = ownerData['displayName'] ?? ownerUsername;
            String assignedRole = 'member';
            if (ownerData['memberRoles'] != null && ownerData['memberRoles'][username] != null) {
              assignedRole = ownerData['memberRoles'][username];
            }
            bool canEdit = false;
            if (ownerData['automationEditors'] != null && (ownerData['automationEditors'] as List).contains(username)) {
              canEdit = true;
            }

            updatedHomes.add(SmartConfig(
              userId: ownerUsername,
              macAddress: ownerData['macAddress'] ?? 'unknown_mac',
              mqttServer: ownerData['mqttServer'] ?? 'broker.emqx.io',
              mqttUser: ownerData['mqttUser'],
              mqttPass: ownerData['mqttPass'],
              devices: ownerDevices,
              role: assignedRole,
              homeName: 'Nhà của $ownerName',
              ownerEmail: ownerUsername,
              canEditAutomation: canEdit,
            ));
          }
        } catch (e) {
          debugPrint("Lỗi tải nhà được mời khi sync: $e");
        }
      }

      await setAvailableHomes(updatedHomes);
      return true;
    } catch (e) {
      debugPrint("Lỗi syncFromFirestore: $e");
      return false;
    }
  }

  /// Gọi hàm này sau khi bạn đã thay đổi trực tiếp (mutate) thuộc tính của activeConfig (ví dụ: đổi tên thiết bị)
  void notifyChanges() {
    notifyListeners();
  }
}
