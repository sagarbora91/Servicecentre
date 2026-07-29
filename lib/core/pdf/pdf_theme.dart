import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

const _regularFontAsset = 'assets/fonts/NotoSansDevanagari-Regular.ttf';
const _boldFontAsset = 'assets/fonts/NotoSansDevanagari-Bold.ttf';

/// Loads the bundled Noto Sans Devanagari family used by printable documents.
///
/// The family includes Latin, Devanagari, Indian currency, and punctuation
/// glyphs, so the same theme safely renders English, Marathi, and Hindi PDFs.
Future<pw.ThemeData> loadPdfTheme() async {
  final regular = await rootBundle.load(_regularFontAsset);
  final bold = await rootBundle.load(_boldFontAsset);
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
  );
}
