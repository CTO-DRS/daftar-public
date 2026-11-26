// تنسيق التاريخ yyyy/MM/dd بأرقام لاتينية (بدون الحاجة لبيانات locale).
import 'number_utils.dart';

String formatDate(DateTime d) => localizeDigits(
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}');
