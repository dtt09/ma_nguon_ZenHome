import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/services/session_manager.dart';

class LoggedDevicesScreen extends StatefulWidget {
  const LoggedDevicesScreen({super.key});

  @override
  State<LoggedDevicesScreen> createState() => _LoggedDevicesScreenState();
}

class _LoggedDevicesScreenState extends State<LoggedDevicesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _currentDeviceId = '';
  String? _username;
  bool _isTrustRequested = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentDeviceId();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    if (user != null) {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user!.uid).get();
      if (query.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _username = query.docs.first.id;
          });
        }
      }
    }
  }

  Future<void> _fetchCurrentDeviceId() async {
    String deviceId = 'unknown_id';
    try {
      deviceId = await SessionManager.getUniqueDeviceId();
    } catch (e) {
      debugPrint("Error fetching device ID: $e");
    }
    
    if (mounted) {
      setState(() {
        _currentDeviceId = deviceId;
      });
    }
  }

  void _revokeSession(String deviceId, String deviceName) async {
    if (user == null) return;
    
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('logout_device_title') ?? 'Đăng xuất thiết bị', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(context.tr('confirm_kick_device')?.replaceAll('{device}', deviceName.isNotEmpty ? deviceName : (context.tr('unknown_device') ?? '')) ?? 'Bạn có chắc chắn muốn đăng xuất thiết bị ${deviceName.isNotEmpty ? deviceName : context.tr('unknown_device')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('btn_cancel') ?? 'Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(context.tr('btn_kick_device') ?? 'Trục xuất')
          ),
        ],
      )
    ) ?? false;

    if (confirm) {
      bool isReauthed = await ReauthHelper.reauthenticate(context, reason: context.tr('reason_kick_device') ?? 'xác nhận trục xuất thiết bị');
      if (!isReauthed) return;
      
      LoadingOverlay.show(context);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_username)
            .collection('sessions')
            .doc(deviceId)
            .update({'isActive': false, 'fcmToken': FieldValue.delete()});
            
        LoadingOverlay.hide();
        if (mounted) {
           showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_kick_success') ?? 'Đã trục xuất thiết bị thành công!');
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_kick_failed') ?? 'Lỗi trục xuất thiết bị', isError: true);
      }
    }
  }

  void _requestTrust(String deviceName) async {
    if (_username == null) return;
    setState(() {
      _isTrustRequested = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_username)
          .collection('alerts')
          .add({
        'type': 'trust_request',
        'deviceName': deviceName,
        'deviceId': _currentDeviceId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_trust_req_sent') ?? 'Đã gửi yêu cầu cấp quyền tin cậy!');
      }
    } catch (e) {
      if (mounted) {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_trust_req_failed') ?? 'Không thể gửi yêu cầu', isError: true);
        setState(() {
          _isTrustRequested = false;
        });
      }
    }
  }

  Widget _buildDeviceItem(Map<String, dynamic> data, String id, bool isCurrentDevice, bool isCurrentDeviceTrusted, bool isDark) {
    final bool isActive = data['isActive'] ?? false;
    final bool isTrusted = data['isTrusted'] ?? false;
    final String deviceName = data['deviceName'] ?? 'Unknown Device';
    final String os = data['os'] ?? 'Unknown OS';
    final String location = data['location'] ?? 'Unknown Location';
    
    final Timestamp? lastLoginTs = data['lastLogin'];
    final Timestamp? lastAccessTs = data['lastAccess'];
    
    String lastLoginStr = 'Unknown';
    if (lastLoginTs != null) {
      lastLoginStr = DateFormat('HH:mm dd/MM/yyyy').format(lastLoginTs.toDate());
    }

    String lastAccessStr = 'Unknown';
    if (lastAccessTs != null) {
      lastAccessStr = DateFormat('HH:mm dd/MM/yyyy').format(lastAccessTs.toDate());
    }

    // Checking if > 30 days
    bool isExpired = false;
    if (lastAccessTs != null) {
       if (DateTime.now().difference(lastAccessTs.toDate()).inDays > 30) {
         isExpired = true;
       }
    }

    final bool effectivelyActive = isActive && !isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121827) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCurrentDevice 
              ? Colors.green.withOpacity(0.5) 
              : (effectivelyActive ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
          width: isCurrentDevice ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                os.toLowerCase().contains('ios') || os.toLowerCase().contains('mac') ? Icons.apple : Icons.phone_android, 
                size: 40, 
                color: isCurrentDevice ? Colors.green : (effectivelyActive ? Colors.blue : Colors.grey)
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceName, 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: effectivelyActive ? null : Colors.grey)
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified_user, color: Colors.blue, size: 16),
                        ],
                        if (isCurrentDevice)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(context.tr('this_device') ?? 'Thiết bị này', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(os, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(location, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.login, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text('${context.tr('last_login') ?? 'Đăng nhập:'} $lastLoginStr', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text('${context.tr('last_access') ?? 'Truy cập cuối:'} $lastAccessStr', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: effectivelyActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    effectivelyActive ? (context.tr('status_logged_in') ?? 'Đang đăng nhập') : (context.tr('status_logged_out') ?? 'Đã đăng xuất'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: effectivelyActive ? Colors.green : Colors.red,
                    ),
                  )
                ],
              ),
              if (effectivelyActive && !isCurrentDevice && isCurrentDeviceTrusted)
                InkWell(
                  onTap: () => _revokeSession(id, deviceName),
                  child: Text(
                    context.tr('btn_logout') ?? 'Đăng xuất',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              if (effectivelyActive && isCurrentDevice && !isTrusted)
                _isTrustRequested
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          context.tr('btn_request_sent') ?? 'Đã gửi ủy quyền',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    : InkWell(
                        onTap: () => _requestTrust(deviceName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            context.tr('btn_request_trust') ?? 'Xin cấp quyền',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.tr('menu_logged_devices') ?? 'Thiết bị đăng nhập', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _username == null 
        ? const Center(child: LogoLoadingIndicator(color: Colors.blue, size: 24))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_username)
                .collection('sessions')
                .orderBy('lastAccess', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LogoLoadingIndicator(color: Colors.blue, size: 24));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.devices_other, size: 60, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      const SizedBox(height: 15),
                      Text(
                        context.tr('msg_no_other_devices') ?? 'Không có thiết bị nào.',
                        style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              
              // Determine if current device is trusted
              bool isCurrentTrusted = false;
              for (var doc in docs) {
                if (doc.id == _currentDeviceId) {
                  final d = doc.data() as Map<String, dynamic>;
                  isCurrentTrusted = d['isTrusted'] ?? false;
                  break;
                }
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(20.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final isCurrent = id == _currentDeviceId;

                  return _buildDeviceItem(data, id, isCurrent, isCurrentTrusted, isDark);
                },
              );
            },
          ),
    );
  }
}
