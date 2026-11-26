import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';

void main() {
  test('release SHA-256 survives metadata parsing and URL changes', () {
    final digest = 'ab' * 32;
    final info = AppVersionInfo.fromJson({'sha256': digest});
    expect(info.copyWith(directApkUrl: 'https://example.test/app.apk').toJson()['sha256'], digest);
  });

  test('APK verification checks the actual bytes, even for equal-length content', () async {
    final dir = await Directory.systemTemp.createTemp('zenhome-hash-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/fixture.apk');
    await file.writeAsBytes([1, 2, 3]);
    final digest = crypto.sha256.convert([1, 2, 3]).toString().toUpperCase();
    expect(await AppUpdateService.hasExpectedApkHash(file, digest), isTrue);
    await file.writeAsBytes([1, 2, 4]);
    expect(await AppUpdateService.hasExpectedApkHash(file, digest), isFalse);
    expect(await AppUpdateService.hasExpectedApkHash(file, null), isFalse);
  });
}
