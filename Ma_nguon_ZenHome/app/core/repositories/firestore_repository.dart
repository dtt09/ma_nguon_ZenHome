import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/services/logger_service.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e, stack) {
      LoggerService.e('Failed to get user data for $userId', e, stack);
    }
    return null;
  }

  Future<void> logDeviceHistory(String userId, String deviceName, String actionText) async {
    try {
      await _firestore.collection('users').doc(userId).collection('history').add({
        'deviceName': deviceName,
        'action': actionText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      LoggerService.e('Failed to log device history', e, stack);
    }
  }

  Stream<DocumentSnapshot> listenToUserDoc(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
