/// تنسيق التاريخ yyyy/MM/dd بأرقام لاتينية (بدون الحاجة لبيانات locale).
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
