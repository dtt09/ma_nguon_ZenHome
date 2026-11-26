import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:zenhome_app/core/services/app_update_service.dart';

class MemberDeviceService {
  static Future<({Uri uri, Map<String, String> headers})> _endpoint(String path) async {
    final base = await AppUpdateService.getLiveServerBaseUrl();
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (!AppUpdateService.isSecureUrl(base) || token == null) {
      throw StateError('Authenticated server unavailable');
    }
    return (uri: Uri.parse('$base/api/v1/$path'), headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
  }

  static Future<Map<String, bool>> confirmedStates(String homeId) async {
    final endpoint = await _endpoint('devices');
    final uri = endpoint.uri.replace(queryParameters: {'userId': homeId});
    final res = await http.get(uri, headers: endpoint.headers).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw StateError('Device state unavailable');
    final devices = jsonDecode(res.body)['data']['devices'] as List;
    return {
      for (final item in devices)
        if (item['isPending'] == false && item['state'] is bool)
          item['id'] as String: item['state'] as bool,
    };
  }

  static Future<bool> setAutomation(List<String> topic, String message) async {
    final home = topic.first;
    final base = topic.take(topic.length - 1).join('/');
    final op = topic.last;
    String path;
    Map<String, dynamic>? data;
    if (op == 'schedule') {
      final schedule = message.split('|');
      if (schedule.length != 5) return false;
      if (schedule[4] == '0') {
        final id = "${base.replaceAll('/', '___')}___${schedule[0]}";
        path = 'schedules/${Uri.encodeComponent(id)}';
      } else {
        path = 'schedules';
        data = {'userId': home, 'baseTopic': base, 'scheduleId': schedule[0],
          'timeOn': schedule[1], 'timeOff': schedule[2], 'days': schedule[3]};
      }
    } else {
      final minutes = int.tryParse(message);
      if (minutes == null || minutes < 0) return false;
      final on = op == 'timer_on';
      if (minutes == 0) {
        final id = "${base}_${on ? 'on' : 'off'}";
        path = 'timers/${Uri.encodeComponent(id)}';
      } else {
        path = 'timers';
        data = {'userId': home, 'baseTopic': base, 'minutes': minutes, 'action': on ? '1' : '0'};
      }
    }
    final endpoint = await _endpoint(path);
    final uri = endpoint.uri.replace(queryParameters: {'userId': home});
    final request = data == null
        ? http.delete(uri, headers: endpoint.headers)
        : http.post(uri, headers: endpoint.headers, body: jsonEncode(data));
    final response = await request.timeout(const Duration(seconds: 8));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<bool> control(String homeId, String id, bool target) async {
    final endpoint = await _endpoint('devices/${Uri.encodeComponent(id)}/control');
    final res = await http.post(endpoint.uri, headers: endpoint.headers,
        body: jsonEncode({'state': target, 'userId': homeId}))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    final statusUri = endpoint.uri.replace(
        path: endpoint.uri.path.substring(0, endpoint.uri.path.lastIndexOf('/')),
        queryParameters: {'userId': homeId});
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final status = await http.get(statusUri, headers: endpoint.headers).timeout(const Duration(seconds: 3));
      if (status.statusCode != 200) return false;
      final device = jsonDecode(status.body)['data'];
      if (device['pendingSync'] == false && device['state'] == target) return true;
    }
    return false;
  }
}
