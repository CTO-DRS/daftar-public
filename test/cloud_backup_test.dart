import 'package:flutter_test/flutter_test.dart';
import 'package:daftar/services/cloud_backup.dart';

void main() {
  test('encrypt/decrypt round trip, wrong passphrase and tampering fail', () async {
    const text = '{"فاتورة":"سري ١٢٣"}';
    final enc = await CloudBackup.encrypt(text, 'كلمة-سر قوية', iterations: 1000);
    expect(String.fromCharCodes(enc).contains('سري'), isFalse);
    expect(await CloudBackup.decrypt(enc, 'كلمة-سر قوية'), text);
    await expectLater(CloudBackup.decrypt(enc, 'خطأ'), throwsA(isA<WrongPassphrase>()));
    final bad = enc.sublist(0)..[40] ^= 1;
    await expectLater(CloudBackup.decrypt(bad, 'كلمة-سر قوية'), throwsA(isA<WrongPassphrase>()));
    final enc2 = await CloudBackup.encrypt(text, 'كلمة-سر قوية', iterations: 1000);
    expect(enc2, isNot(enc)); // fresh salt+nonce each time
  });
}
