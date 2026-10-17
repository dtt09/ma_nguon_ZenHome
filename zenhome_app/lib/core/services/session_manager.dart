import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:package_info_plus/package_info_plus.dart';

class SessionManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _storage = FlutterSecureStorage();

  static Future<String> getUniqueDeviceId() async {
    String? id = await _storage.read(key: 'zenhome_device_id');
    if (id != null) return id;

    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      id = 'android_${androidInfo.id}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (iosInfo.identifierForVendor != null && iosInfo.identifierForVendor!.isNotEmpty) {
         id = 'ios_${iosInfo.identifierForVendor}';
      }
    }
    
    if (id == null) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    await _storage.write(key: 'zenhome_device_id', value: id);
    return id;
  }

  /// Logs the current session to Firestore
  static Future<void> recordSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? username;
    final query = await _firestore.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown Device';
      String osVersion = 'Unknown OS';
      String deviceId = 'unknown_id';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
        deviceId = await getUniqueDeviceId();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        deviceId = await getUniqueDeviceId();
      }

      // Lấy vị trí từ GPS (chính xác hơn), nếu không được mới lấy qua IP
      String location = 'Unknown Location';
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
            List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
            if (placemarks.isNotEmpty) {
              geocoding.Placemark place = placemarks[0];
              String loc = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';
              String country = place.country ?? '';
              if (loc.isNotEmpty && country.isNotEmpty) {
                 location = '$loc, $country';
              } else if (loc.isNotEmpty) {
                 location = loc;
              } else if (country.isNotEmpty) {
                 location = country;
              }
            }
          }
        }
      } catch (e) {
        print('Error getting GPS for session: $e');
      }

      // Fallback to IP if GPS is not available or permission denied
      if (location == 'Unknown Location') {
        try {
          final response = await http.get(Uri.parse('https://ipwho.is/'));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              location = '${data['city']}, ${data['country']}';
            }
          }
        } catch (e) {
          print('Error fetching IP location: $e');
        }
      }

      final sessionRef = _firestore
          .collection('users')
          .doc(username)
          .collection('sessions')
          .doc(deviceId);
          
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        print('Error getting FCM token: $e');
      }

      final docSnapshot = await sessionRef.get();
      bool isNewDevice = !docSnapshot.exists;
      bool isTrusted = false;

      if (isNewDevice) {
        // If it's the very first device for this user, make it trusted automatically.
        final allSessions = await _firestore.collection('users').doc(username).collection('sessions').get();
        if (allSessions.docs.isEmpty) {
          isTrusted = true;
        } else {
          // Send New Login Alert
          await _firestore.collection('users').doc(username).collection('alerts').add({
            'type': 'new_login',
            'deviceName': deviceName,
            'location': location,
            'timestamp': FieldValue.serverTimestamp(),
            'deviceId': deviceId,
          });
        }
      } else {
        // Preserve previous trust state if it exists
        final data = docSnapshot.data() as Map<String, dynamic>;
        isTrusted = data['isTrusted'] ?? false;
      }

      String appVersion = '1.5.0';
      int buildNumber = 150;
      try {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = pkg.version;
        buildNumber = int.tryParse(pkg.buildNumber) ?? 150;
      } catch (_) {}

      await sessionRef.set({
        'deviceName': deviceName,
        'os': osVersion,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'location': location,
        'lastLogin': FieldValue.serverTimestamp(),
        'lastAccess': FieldValue.serverTimestamp(),
        'isActive': true,
        if (isNewDevice) 'firstSeen': FieldValue.serverTimestamp(),
        'isTrusted': isTrusted,
        if (fcmToken != null) 'fcmToken': fcmToken,
      }, SetOptions(merge: true));

    } catch (e) {
      print('Error recording session: $e');
    }
  }

  /// Pings the session to update lastAccess. Handles 30-day expiry.
  static Future<void> updateLastAccess() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? username;
    final query = await _firestore.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_id';

      if (Platform.isAndroid) {
        deviceId = await getUniqueDeviceId();
      } else if (Platform.isIOS) {
        deviceId = await getUniqueDeviceId();
      }

      final sessionRef = _firestore
          .collection('users')
          .doc(username)
          .collection('sessions')
          .doc(deviceId);
          
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        print('Error getting FCM token: $e');
      }

      final doc = await sessionRef.get();
      if (!doc.exists) {
        await recordSession();
        return;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['isActive'] == true) {
        final Timestamp? lastAccessTimestamp = data['lastAccess'];
        if (lastAccessTimestamp != null) {
          final lastAccessDate = lastAccessTimestamp.toDate();
          final difference = DateTime.now().difference(lastAccessDate).inDays;

          if (difference > 30) {
            // Expired session
            await sessionRef.update({'isActive': false});
            await _auth.signOut();
            return;
          }
        }
      } else if (data != null && data['isActive'] == false) {
        // Already logged out from another device
        await _auth.signOut();
        return;
      }

      if (data != null) {
        // Check if it's eligible to be trusted (15 days)
        bool isTrusted = data['isTrusted'] ?? false;
        if (!isTrusted && data['firstSeen'] != null) {
           final firstSeenTimestamp = data['firstSeen'] as Timestamp;
           final firstSeenDiff = DateTime.now().difference(firstSeenTimestamp.toDate()).inDays;
           if (firstSeenDiff >= 15) {
              isTrusted = true;
           }
        }

        String appVersion = '1.5.0';
        int buildNumber = 150;
        try {
          final pkg = await PackageInfo.fromPlatform();
          appVersion = pkg.version;
          buildNumber = int.tryParse(pkg.buildNumber) ?? 150;
        } catch (_) {}

        // Update last access, app version, and possibly trust status
        await sessionRef.update({
          'lastAccess': FieldValue.serverTimestamp(),
          'isTrusted': isTrusted,
          'appVersion': appVersion,
          'buildNumber': buildNumber,
          'isActive': true,
          if (fcmToken != null) 'fcmToken': fcmToken,
        });
      }
    } catch (e) {
      print('Error updating session access: $e');
    }
  }

  /// Clears the current session (used on Logout)
  static Future<void> clearSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? username;
    final query = await _firestore.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_id';

      if (Platform.isAndroid) {
        deviceId = await getUniqueDeviceId();
      } else if (Platform.isIOS) {
        deviceId = await getUniqueDeviceId();
      }

      final sessionRef = _firestore
          .collection('users')
          .doc(username)
          .collection('sessions')
          .doc(deviceId);

      await sessionRef.update({
        'isActive': false,
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      print('Error clearing session: $e');
    }
  }

  /// Kiểm tra xem thiết bị hiện tại có phải là thiết bị tin cậy không
  static Future<bool> isCurrentDeviceTrusted() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    String? username;
    final query = await _firestore.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_id';

      if (Platform.isAndroid) {
        deviceId = await getUniqueDeviceId();
      } else if (Platform.isIOS) {
        deviceId = await getUniqueDeviceId();
      }

      final doc = await _firestore
          .collection('users')
          .doc(username)
          .collection('sessions')
          .doc(deviceId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isTrusted'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking trusted device: $e');
      return false;
    }
  }
}
