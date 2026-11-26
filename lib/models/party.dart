/// عميل أو مورد محفوظ.
class Party {
  int? id;
  String name;
  String phone;
  String address;
  String notes;

  Party({this.id, required this.name, this.phone = '', this.address = '', this.notes = ''});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'phone': phone, 'address': address, 'notes': notes};

  factory Party.fromMap(Map<String, Object?> m) => Party(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

class PartySummary {
  final Party party;
  final int invoiceCount;
  final double total;
  PartySummary(this.party, this.invoiceCount, this.total);
}
