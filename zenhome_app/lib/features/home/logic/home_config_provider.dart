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
    macAddress: '',
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
      _activeConfig = SmartConfig(userId: 'guest', macAddress: '', devices: []);
    }
    
    await _secureStorage.write(key: 'active_home_id', value: _activeConfig.userId);
    await _secureStorage.write(key: 'available_homes', value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearAllHomes() async {
    _availableHomes = [];
    _activeConfig = SmartConfig(
      userId: 'guest',
      macAddress: '',
      devices: [],
    );
    await _secureStorage.delete(key: 'active_home_id');
    await _secureStorage.delete(key: 'available_homes');
    notifyListeners();
  }

  /// Tạo ngôi nhà mới do chính tài khoản này làm chủ
  Future<SmartConfig?> createNewHome({
    required String homeName,
    String? macAddress,
    String homeIcon = 'home',
    String homeType = 'townhouse',
    String homeColor = '#0F766E',
    List<String> homeRules = const [],
  }) async {
    try {
      final trimmedName = homeName.trim();
      if (trimmedName.isEmpty) return null;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      // Tìm username gốc của người dùng
      String primaryUsername = '';
      final ownHomes = _availableHomes.where((h) => !h.isSubHome && h.role == 'owner').toList();
      if (ownHomes.isNotEmpty) {
        primaryUsername = ownHomes.first.userId;
      } else {
        final q = await FirebaseFirestore.instance.collection('users')
            .where('uid', isEqualTo: currentUser.uid)
            .get();
        for (var doc in q.docs) {
          if (doc.data()['isSubHome'] != true) {
            primaryUsername = doc.id;
            break;
          }
        }
        if (primaryUsername.isEmpty && q.docs.isNotEmpty) {
          primaryUsername = q.docs.first.id;
        }
      }
      if (primaryUsername.isEmpty) {
        primaryUsername = currentUser.email?.split('@')[0] ?? 'user_${currentUser.uid.substring(0, 6)}';
      }

      // Tạo ID duy nhất cho nhà phụ: {primaryUsername}_home_{timestamp}
      final homeId = '${primaryUsername}_home_${DateTime.now().millisecondsSinceEpoch}';

      final cleanMac = (macAddress != null && macAddress.trim().isNotEmpty)
          ? macAddress.trim().replaceAll(':', '').replaceAll('-', '').toUpperCase()
          : '';

      final newHomeData = {
        'uid': currentUser.uid,
        'ownerUsername': primaryUsername,
        'displayName': trimmedName,
        'homeName': trimmedName,
        'role': 'owner',
        'macAddress': cleanMac,
        'mqttServer': 'broker.emqx.io',
        'devices': <Map<String, dynamic>>[],
        'isSubHome': true,
        'homeIcon': homeIcon,
        'homeType': homeType,
        'homeColor': homeColor,
        'homeRules': homeRules,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Tạo document nhà mới trong collection users
      await FirebaseFirestore.instance.collection('users').doc(homeId).set(newHomeData);

      // 2. Cập nhật danh sách subHomeIds vào document chính
      try {
        await FirebaseFirestore.instance.collection('users').doc(primaryUsername).set({
          'subHomeIds': FieldValue.arrayUnion([homeId]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Lỗi ghi subHomeIds: $e");
      }

      final newHomeConfig = SmartConfig(
        userId: homeId,
        macAddress: cleanMac,
        mqttServer: 'broker.emqx.io',
        devices: [],
        role: 'owner',
        homeName: trimmedName,
        ownerEmail: primaryUsername,
        canEditAutomation: true,
        isSubHome: true,
        homeIcon: homeIcon,
        homeType: homeType,
        homeColor: homeColor,
        homeRules: homeRules,
      );

      _availableHomes.add(newHomeConfig);
      await switchActiveHome(homeId);
      return newHomeConfig;
    } catch (e) {
      debugPrint("Lỗi tạo nhà mới: $e");
      return null;
    }
  }

  /// Cập nhật thuộc tính, biểu tượng, màu sắc và bộ quy tắc ngôi nhà
  Future<bool> updateHomeProperties({
    required String homeId,
    String? homeName,
    String? homeIcon,
    String? homeType,
    String? homeColor,
    List<String>? homeRules,
  }) async {
    try {
      final idx = _availableHomes.indexWhere((h) => h.userId == homeId);
      if (idx == -1) return false;

      final home = _availableHomes[idx];
      if (homeName != null && homeName.trim().isNotEmpty) {
        home.homeName = homeName.trim();
      }
      if (homeIcon != null) home.homeIcon = homeIcon;
      if (homeType != null) home.homeType = homeType;
      if (homeColor != null) home.homeColor = homeColor;
      if (homeRules != null) home.homeRules = List.from(homeRules);

      if (_activeConfig.userId == homeId) {
        _activeConfig = home;
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (homeName != null && homeName.trim().isNotEmpty) {
        updateData['homeName'] = homeName.trim();
        updateData['displayName'] = homeName.trim();
      }
      if (homeIcon != null) updateData['homeIcon'] = homeIcon;
      if (homeType != null) updateData['homeType'] = homeType;
      if (homeColor != null) updateData['homeColor'] = homeColor;
      if (homeRules != null) updateData['homeRules'] = homeRules;

      await FirebaseFirestore.instance.collection('users').doc(homeId).set(
        updateData,
        SetOptions(merge: true),
      );

      await _secureStorage.write(
        key: 'available_homes',
        value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Lỗi cập nhật thuộc tính nhà: $e");
      return false;
    }
  }

  /// Đảm bảo tính độc quyền của MAC: 1 phần cứng ESP32 chỉ thuộc về DUY NHẤT 1 ngôi nhà.
  /// Nếu bất kỳ ngôi nhà nào khác đang giữ MAC này, tự động giải phóng về '' (Chưa liên kết) để tránh xung đột chéo.
  Future<void> claimExclusiveMacAddress(String homeId, String newMac) async {
    final cleanMac = newMac.trim().toUpperCase();
    if (cleanMac.isEmpty || cleanMac == 'UNKNOWN_MAC') return;

    bool changed = false;
    for (var home in _availableHomes) {
      if (home.userId != homeId && home.macAddress.toUpperCase() == cleanMac) {
        debugPrint('[EXCLUSIVE-MAC] 🔄 Ngôi nhà "${home.homeName}" (${home.userId}) đang giữ MAC $cleanMac. Đang giải phóng về trạng thái chưa liên kết...');
        home.macAddress = '';
        changed = true;
        try {
          await FirebaseFirestore.instance.collection('users').doc(home.userId).set({
            'macAddress': '',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[EXCLUSIVE-MAC] Lỗi giải phóng MAC trên Firebase: $e');
        }
      }
    }

    final targetIdx = _availableHomes.indexWhere((h) => h.userId == homeId);
    if (targetIdx != -1) {
      _availableHomes[targetIdx].macAddress = cleanMac;
      changed = true;
    }
    if (_activeConfig.userId == homeId) {
      _activeConfig.macAddress = cleanMac;
      changed = true;
    }

    if (changed) {
      await _secureStorage.write(
        key: 'available_homes',
        value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()),
      );
      notifyListeners();
    }
  }

  /// Đổi tên một ngôi nhà
  Future<bool> renameHome(String homeId, String newName) async {
    try {
      final trimmed = newName.trim();
      if (trimmed.isEmpty) return false;

      final idx = _availableHomes.indexWhere((h) => h.userId == homeId);
      if (idx == -1) return false;

      _availableHomes[idx].homeName = trimmed;
      if (_activeConfig.userId == homeId) {
        _activeConfig.homeName = trimmed;
      }

      await FirebaseFirestore.instance.collection('users').doc(homeId).set({
        'homeName': trimmed,
        'displayName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _secureStorage.write(key: 'available_homes', value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Lỗi đổi tên nhà: $e");
      return false;
    }
  }

  /// Xóa một ngôi nhà phụ do mình làm chủ (Không cho phép xóa nhà chính mặc định)
  Future<bool> deleteHome(String homeId) async {
    try {
      final homeToDelete = _availableHomes.firstWhere((h) => h.userId == homeId, orElse: () => _activeConfig);
      // Chỉ cho phép xóa nhà phụ (isSubHome == true)
      if (!homeToDelete.isSubHome) {
        debugPrint("Không thể xóa nhà chính mặc định!");
        return false;
      }

      // Xóa document trên Firestore
      await FirebaseFirestore.instance.collection('users').doc(homeId).delete();

      // Cập nhật document chính
      final primaryHome = _availableHomes.firstWhere((h) => !h.isSubHome, orElse: () => _availableHomes.first);
      try {
        await FirebaseFirestore.instance.collection('users').doc(primaryHome.userId).update({
          'subHomeIds': FieldValue.arrayRemove([homeId]),
        });
      } catch (_) {}

      // Xóa khỏi danh sách local
      _availableHomes.removeWhere((h) => h.userId == homeId);
      if (_activeConfig.userId == homeId) {
        _activeConfig = primaryHome;
        await _secureStorage.write(key: 'active_home_id', value: _activeConfig.userId);
      }

      await _secureStorage.write(key: 'available_homes', value: jsonEncode(_availableHomes.map((e) => e.toJson()).toList()));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Lỗi xóa nhà: $e");
      return false;
    }
  }

  /// Đồng bộ trực tiếp 100% dữ liệu tài khoản, thiết bị và tất cả các nhà từ Cloud Firestore
  Future<bool> syncFromFirestore({String? targetUsername}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // 1. Tìm tất cả các nhà mà tài khoản này sở hữu (uid == currentUser.uid)
      final ownDocsQuery = await FirebaseFirestore.instance.collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .get();

      if (ownDocsQuery.docs.isEmpty) return false;

      // Xác định username của nhà chính (doc có isSubHome != true)
      String primaryUsername = '';
      for (var doc in ownDocsQuery.docs) {
        final data = doc.data();
        if (data['isSubHome'] != true) {
          primaryUsername = doc.id;
          break;
        }
      }
      if (primaryUsername.isEmpty) primaryUsername = ownDocsQuery.docs.first.id;

      List<SmartConfig> updatedHomes = [];

      // Nạp tất cả các nhà sở hữu (cả nhà chính và các nhà phụ)
      for (var doc in ownDocsQuery.docs) {
        final data = doc.data();
        final homeId = doc.id;
        final bool isSub = (data['isSubHome'] == true) || (homeId != primaryUsername);

        List<DeviceConfig> restoredDevices = [];
        if (data['devices'] != null) {
          restoredDevices = (data['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
        }

        String fallbackName = isSub ? 'Nhà phụ' : 'Nhà chính của tôi';
        String homeName = data['homeName'] ?? data['displayName'] ?? fallbackName;

        final rawHomeMac = data['macAddress']?.toString() ?? '';
        final cleanHomeMac = (rawHomeMac == 'unknown_mac' || rawHomeMac == 'unknown') ? '' : rawHomeMac;

        updatedHomes.add(SmartConfig(
          userId: homeId,
          macAddress: cleanHomeMac,
          mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
          mqttUser: data['mqttUser'],
          mqttPass: data['mqttPass'],
          devices: restoredDevices,
          role: 'owner',
          homeName: homeName,
          ownerEmail: primaryUsername,
          canEditAutomation: true,
          isSubHome: isSub,
          homeIcon: data['homeIcon'] ?? 'home',
          homeType: data['homeType'] ?? 'townhouse',
          homeColor: data['homeColor'] ?? '#0F766E',
          homeRules: data['homeRules'] != null ? List<String>.from(data['homeRules']) : [],
        ));
      }

      // 2. Tìm các nhà được chia sẻ (Shared Homes):
      // A. Qua trường ownerUsername trên document chính
      final primaryDoc = ownDocsQuery.docs.firstWhere((d) => d.id == primaryUsername, orElse: () => ownDocsQuery.docs.first);
      final primaryData = primaryDoc.data();

      List<String> sharedOwnerUsernames = [];
      if (primaryData['ownerUsername'] != null && primaryData['ownerUsername'].toString().isNotEmpty) {
        sharedOwnerUsernames.add(primaryData['ownerUsername'].toString());
      }

      // B. Qua trường sharedWith trên các document khác
      try {
        final sharedWithQuery = await FirebaseFirestore.instance.collection('users')
            .where('sharedWith', arrayContains: primaryUsername)
            .get();
        for (var doc in sharedWithQuery.docs) {
          if (!sharedOwnerUsernames.contains(doc.id) && doc.id != primaryUsername) {
            sharedOwnerUsernames.add(doc.id);
          }
        }
      } catch (e) {
        debugPrint("Lỗi query sharedWith: $e");
      }

      // Tải thông tin từng nhà được chia sẻ
      for (String ownerUsername in sharedOwnerUsernames) {
        if (updatedHomes.any((h) => h.userId == ownerUsername)) continue;
        try {
          final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUsername).get();
          if (ownerDoc.exists && ownerDoc.data() != null) {
            final ownerData = ownerDoc.data() as Map<String, dynamic>;
            List<DeviceConfig> ownerDevices = [];
            if (ownerData['devices'] != null) {
              ownerDevices = (ownerData['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
            }
            String ownerName = ownerData['displayName'] ?? ownerUsername;
            String assignedRole = 'member';
            if (ownerData['memberRoles'] != null && ownerData['memberRoles'][primaryUsername] != null) {
              assignedRole = ownerData['memberRoles'][primaryUsername];
            }
            bool canEdit = false;
            if (assignedRole == 'co_owner' ||
                (ownerData['automationEditors'] != null && (ownerData['automationEditors'] as List).contains(primaryUsername))) {
              canEdit = true;
            }

            List<String>? allowedDevs;
            if (ownerData['memberDevicePermissions'] != null &&
                ownerData['memberDevicePermissions'][primaryUsername] != null) {
              allowedDevs = List<String>.from(ownerData['memberDevicePermissions'][primaryUsername]);
            }

            bool isUserDisabled = false;
            if (ownerData['disabledMembers'] != null && (ownerData['disabledMembers'] as List).contains(primaryUsername)) {
              isUserDisabled = true;
            }

            final rawOwnerMac = ownerData['macAddress']?.toString() ?? '';
            final cleanOwnerMac = (rawOwnerMac == 'unknown_mac' || rawOwnerMac == 'unknown') ? '' : rawOwnerMac;

            updatedHomes.add(SmartConfig(
              userId: ownerUsername,
              macAddress: cleanOwnerMac,
              mqttServer: ownerData['mqttServer'] ?? 'broker.emqx.io',
              mqttUser: ownerData['mqttUser'],
              mqttPass: ownerData['mqttPass'],
              devices: ownerDevices,
              role: assignedRole,
              homeName: 'Nhà của $ownerName',
              ownerEmail: ownerUsername,
              canEditAutomation: canEdit,
              allowedDevices: allowedDevs,
              isDisabled: isUserDisabled,
              isSubHome: false,
              homeIcon: ownerData['homeIcon'] ?? 'home',
              homeType: ownerData['homeType'] ?? 'townhouse',
              homeColor: ownerData['homeColor'] ?? '#0F766E',
              homeRules: ownerData['homeRules'] != null ? List<String>.from(ownerData['homeRules']) : [],
            ));
          }
        } catch (e) {
          debugPrint("Lỗi tải nhà chia sẻ $ownerUsername: $e");
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
