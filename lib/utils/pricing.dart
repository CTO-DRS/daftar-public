/// شريحة سعر حسب الكمية: من [minQty] فأكثر يُطبَّق [price] للوحدة.
class PriceTier {
  final double minQty;
  final double price;
  const PriceTier(this.minQty, this.price);
}

/// مفتاح الصنف للشرائح: الكود إن وُجد وإلا الوصف (بدون فروق حالة أو مسافات).
String tierKey(String code, String description) {
  final c = code.trim();
  return c.isNotEmpty ? 'c:${c.toLowerCase()}' : 'd:${description.trim().toLowerCase()}';
}

/// سعر الشريحة الأنسب للكمية، أو null إن لم تنطبق أي شريحة.
double? tierPrice(List<PriceTier> tiers, double qty) {
  PriceTier? best;
  for (final t in tiers) {
    if (t.minQty <= qty && (best == null || t.minQty > best.minQty)) best = t;
  }
  return best?.price;
}
