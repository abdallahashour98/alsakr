import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart' as bidi;

extension ArabicTextExtension on String {
  /// يعالج النص لجعل الحروف العربية المتصلة تظهر بشكل صحيح في الـ PDF
  /// ويقوم بعكس اتجاهها لكي ترسم الحروف من اليمين لليسار.
  String get reshapeArabic {
    if (trim().isEmpty) return this;
    final reshaped = ArabicReshaper.instance.reshape(this);
    // logicalToVisual returns List<int> codepoints, convert back to String
    final visual = bidi.logicalToVisual(reshaped);
    return String.fromCharCodes(visual);
  }
}
