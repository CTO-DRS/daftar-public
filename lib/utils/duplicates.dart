import 'auto_fill.dart' show normArabic;
import 'number_utils.dart';

/// عميل أو صنف مرشّح للدمج.
class DupEntry {
  final String name;
  final String phone;
  final String code;
  final int count; // عدد الفواتير/الأسطر المرتبطة
  const DupEntry(this.name, {this.phone = '', this.code = '', this.count = 0});
}

class DupGroup {
  /// الأول هو المقترح للإبقاء (الأكثر استخداماً).
  final List<DupEntry> entries;
  final String reason;
  const DupGroup(this.entries, this.reason);
}

int _lev(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// الأرقام فقط: «كولا 330» و«كولا 335» صنفان مختلفان وليسا خطأ إملائي.
String _digits(String s) => normalizeDigits(s).replaceAll(RegExp(r'[^0-9]'), '');

String _tokensKey(String n) => (n.split(' ')..sort()).join(' ');

String _phoneKey(String p) {
  final d = normalizeDigits(p).replaceAll(RegExp(r'[^0-9]'), '');
  return d.length >= 8 ? d.substring(d.length - 8) : '';
}

/// يجمع المرشحين المتشابهين: نفس الاسم بعد التطبيع، نفس الكلمات بترتيب مختلف، فرق حرف واحد
/// (أسماء 5 أحرف فأكثر)، نفس الجوال، أو نفس الكود إن [byCode]. لا يدمج شيئاً بنفسه.
List<DupGroup> findDuplicateGroups(List<DupEntry> all,
    {bool byPhone = true, bool byCode = false}) {
  final n = all.length;
  final parent = List<int>.generate(n, (i) => i);
  int find(int x) => parent[x] == x ? x : parent[x] = find(parent[x]);
  final reasons = <int, String>{};
  void union(int a, int b, String why) {
    final ra = find(a), rb = find(b);
    if (ra == rb) return;
    parent[rb] = ra;
    reasons.putIfAbsent(ra, () => why);
  }

  final norm = [for (final e in all) normArabic(e.name)];
  for (var i = 0; i < n; i++) {
    if (norm[i].isEmpty) continue;
    for (var j = i + 1; j < n; j++) {
      if (norm[j].isEmpty) continue;
      if (norm[i] == norm[j]) {
        union(i, j, 'نفس الاسم');
      } else if (_tokensKey(norm[i]) == _tokensKey(norm[j])) {
        union(i, j, 'نفس الكلمات بترتيب مختلف');
      } else if (norm[i].length >= 5 && norm[j].length >= 5 && _digits(norm[i]) == _digits(norm[j]) && _lev(norm[i], norm[j]) <= 1) {
        union(i, j, 'فرق حرف واحد');
      } else if (byPhone && _phoneKey(all[i].phone).isNotEmpty && _phoneKey(all[i].phone) == _phoneKey(all[j].phone)) {
        union(i, j, 'نفس رقم الجوال');
      } else if (byCode && all[i].code.trim().isNotEmpty && all[i].code.trim().toLowerCase() == all[j].code.trim().toLowerCase()) {
        union(i, j, 'نفس كود الموديل');
      }
    }
  }
  final groups = <int, List<DupEntry>>{};
  for (var i = 0; i < n; i++) {
    groups.putIfAbsent(find(i), () => []).add(all[i]);
  }
  final out = <DupGroup>[];
  groups.forEach((root, l) {
    if (l.length < 2) return;
    l.sort((a, b) => b.count.compareTo(a.count));
    out.add(DupGroup(l, reasons[root] ?? 'متشابهان'));
  });
  out.sort((a, b) => b.entries.length.compareTo(a.entries.length));
  return out;
}
