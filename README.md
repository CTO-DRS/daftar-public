# دفتر (Daftar)

تطبيق أندرويد عربي (RTL) لإنشاء وإدارة الفواتير وجداول الجرد، مع مسح الفواتير الورقية بالكاميرا (OCR) وتصديرها PDF احترافي.

- Flutter / Dart، قاعدة بيانات SQLite محلية (تعمل بدون إنترنت)
- جدول أصناف ديناميكي: م، كود الصنف، الرقم المرجعي، النوع، العدد، سعر الفردي، الإجمالي، ملاحظات
- تثبيت السعر/النوع لإدخال أسطر متكررة بضغطة، شريط إجماليات ثابت، ترتيب وفلترة
- مسح بالكاميرا: قص وتدوير، Gemini أو OpenRouter (مفتاحك من الإعدادات)، وبديل محلي ML Kit، وشاشة مراجعة تلوّن الصفوف المشكوك فيها
- PDF بخط Amiri المضمّن: معاينة، مشاركة (واتساب)، حفظ في Download/Daftar

## البنية
`lib/models` `lib/database` `lib/services` `lib/screens` `lib/widgets` `lib/utils`

## البناء
GitHub Actions (`.github/workflows/build_apk.yml`) يبني `app-release.apk` ويرفعه كـ Artifact مع كل push.
محلياً: `flutter pub get && flutter build apk --release`

الخطوط: Amiri و Cairo (SIL Open Font License).
