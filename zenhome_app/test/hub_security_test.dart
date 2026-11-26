import 'package:flutter_test/flutter_test.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/services/hub_local_key.dart';
import 'package:zenhome_app/core/services/zenhome_crypto.dart';

void main() {
  test('HMAC SHA-256 agrees with the RFC 4231 test vector', () {
    final proof = ZenHomeCrypto.sign('0b' * 20, 'Hi There');
    expect(proof, 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');
    expect(ZenHomeCrypto.matches(proof, proof), isTrue);
    expect(ZenHomeCrypto.matches(proof, null), isFalse);
    expect(ZenHomeCrypto.matches(proof, proof.replaceFirst('b', 'a')), isFalse);
  });

  test('Owner envelopes round-trip and reject altered authentication tags', () {
    final key = HubLocalKey.generate();
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    const body = '{"wifi_ssid":"Tầng hai"}';
    final sealed = ZenHomeCrypto.encryptPayload(plaintext: body, keyHex: key);
    expect(ZenHomeCrypto.decryptPayload(envelope: sealed, keyHex: key), body);
    final changed = sealed.substring(0, sealed.length - 1) + (sealed.endsWith('0') ? '1' : '0');
    expect(ZenHomeCrypto.decryptPayload(envelope: changed, keyHex: key), isNull);
  });

  test('Legacy shared-home snapshots discard owner credentials on load', () {
    for (final role in ['member', 'co_owner']) {
      final config = SmartConfig.fromJson({'role': role, 'userId': 'shared',
        'adminPass': 'old-secret', 'mqttUser': 'old-user', 'mqttPass': 'old-pass'});
      expect(config.adminPass, isEmpty);
      expect(config.mqttUser, isNull);
      expect(config.mqttPass, isNull);
    }
  });
}
