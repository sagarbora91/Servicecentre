import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

const _regularFontAsset = 'assets/fonts/NotoSans-Regular.ttf';
const _boldFontAsset = 'assets/fonts/NotoSans-Bold.ttf';
const _devanagariFontAsset = 'assets/fonts/NotoSansDevanagari-Regular.ttf';

/// Loads bundled Noto Sans fonts used by printable documents.
///
/// Latin text uses the base family while Marathi and Hindi glyphs fall back to
/// Noto Sans Devanagari, keeping all three app languages available offline.
Future<pw.ThemeData> loadPdfTheme() async {
  final regular = await rootBundle.load(_regularFontAsset);
  final bold = await rootBundle.load(_boldFontAsset);
  final devanagari = await rootBundle.load(_devanagariFontAsset);
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
    fontFallback: [pw.Font.ttf(devanagari)],
  );
}
