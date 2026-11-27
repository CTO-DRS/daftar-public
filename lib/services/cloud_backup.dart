import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_service.dart';
import 'sync_service.dart';

class WrongPassphrase implements Exception {
  @override
  String toString() => 'عبارة المرور غير صحيحة أو النسخة تالفة';
}

/// نسخة سحابية مشفرة من جهة العميل (AES-256-GCM، المفتاح من عبارة مرور عبر PBKDF2).
/// الخادم لا يرى إلا بيانات مشفرة؛ ضياع العبارة يعني ضياع النسخة (لا استرجاع).
class CloudBackup {
  CloudBackup._();
  static const magic = [0x44, 0x46, 0x42, 0x31]; // DFB1
  static const defaultIterations = 200000;
  static const maxBytes = 4 * 1024 * 1024;

  static Future<SecretKey> _key(String pass, List<int> salt, int iters) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iters, bits: 256)
          .deriveKeyFromPassword(password: pass, nonce: salt);

  static Future<Uint8List> encrypt(String plain, String pass,
      {int iterations = defaultIterations}) async {
    final algo = AesGcm.with256bits();
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _key(pass, salt, iterations);
    final box = await algo.encrypt(utf8.encode(plain), secretKey: key);
    final out = BytesBuilder()
      ..add(magic)
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, iterations))
      ..add(salt)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<String> decrypt(Uint8List data, String pass) async {
    if (data.length < 4 + 4 + 16 + 12 + 16 || !_eq(data.sublist(0, 4), magic)) {
      throw WrongPassphrase();
    }
    final iters = data.buffer.asByteData(data.offsetInBytes + 4, 4).getUint32(0);
    final salt = data.sublist(8, 24);
    final nonce = data.sublist(24, 36);
    final mac = data.sublist(data.length - 16);
    final ct = data.sublist(36, data.length - 16);
    try {
      final key = await _key(pass, salt, iters);
      final plain = await AesGcm.with256bits()
          .decrypt(SecretBox(ct, nonce: nonce, mac: Mac(mac)), secretKey: key);
      return utf8.decode(plain);
    } catch (_) {
      throw WrongPassphrase();
    }
  }

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---- الخادم ----

  static Future<DateTime> upload(String pass, {int iterations = defaultIterations}) async {
    final s = SyncService.instance;
    final token = await s.accessToken();
    final enc = await encrypt(await BackupService.exportJson(), pass, iterations: iterations);
    if (enc.length > maxBytes) throw SyncException('النسخة كبيرة جداً للرفع (أكثر من 4 ميجا)');
    final base = '${s.baseUrl}/rest/v1/backups';
    final h = s.headers(token, 'daftar', true);
    // الأحدث يصبح "السابقة" قبل الكتابة.
    final cur = await s.client.get(Uri.parse('$base?select=data,size&slot=eq.latest'),
        headers: s.headers(token, 'daftar'));
    if (cur.statusCode >= 300) throw SyncException('تعذر الاتصال بالخادم');
    final prev = jsonDecode(utf8.decode(cur.bodyBytes)) as List;
    final up = {...h, 'Prefer': 'resolution=merge-duplicates,return=minimal'};
    final url = Uri.parse('$base?on_conflict=user_id,slot');
    if (prev.isNotEmpty) {
      final r = await s.client.post(url,
          headers: up,
          body: jsonEncode({'slot': 'previous', 'data': prev.first['data'], 'size': prev.first['size']}));
      if (r.statusCode >= 300) throw SyncException('تعذر رفع النسخة');
    }
    final r = await s.client.post(url,
        headers: up,
        body: jsonEncode({'slot': 'latest', 'data': base64.encode(enc), 'size': enc.length}));
    if (r.statusCode >= 300) throw SyncException('تعذر رفع النسخة');
    return DateTime.now();
  }

  /// يجلب النسخة المشفرة ويفكها. [previous] لاسترجاع النسخة قبل الأخيرة.
  static Future<String?> download(String pass, {bool previous = false}) async {
    final s = SyncService.instance;
    final token = await s.accessToken();
    final r = await s.client.get(
        Uri.parse('${s.baseUrl}/rest/v1/backups?select=data&slot=eq.${previous ? 'previous' : 'latest'}'),
        headers: s.headers(token, 'daftar'));
    if (r.statusCode >= 300) throw SyncException('تعذر الاتصال بالخادم');
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    if (list.isEmpty) return null;
    return decrypt(base64.decode(list.first['data'] as String), pass);
  }
}
