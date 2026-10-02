import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/export/export_download.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Client-side PDF / Excel / CSV export for investor (and future) reports.
class ExportEngine {
  ExportEngine._();

  static final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  static final _date = DateFormat.yMMMd();

  static Future<void> sharePdf({
    required String filename,
    required Uint8List bytes,
  }) async {
    await saveBytes(
      filename: filename.endsWith('.pdf') ? filename : '$filename.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  /// Downloads in the browser. Other platforms open the share sheet.
  static Future<void> saveBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      downloadExportBytes(
        filename: filename,
        bytes: bytes,
        mimeType: mimeType,
      );
      return;
    }
    await Share.shareXFiles([
      XFile.fromData(bytes, mimeType: mimeType, name: filename),
    ]);
  }

  static Future<void> shareExcel({
    required String filename,
    required Uint8List bytes,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: filename.endsWith('.xlsx') ? filename : '$filename.xlsx',
      ),
    ]);
  }

  static Future<void> sharePng({
    required String filename,
    required Uint8List bytes,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: filename.endsWith('.png') ? filename : '$filename.png',
      ),
    ]);
  }

  static Future<void> shareCsv({
    required String filename,
    required String csv,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: filename.endsWith('.csv') ? filename : '$filename.csv',
      ),
    ]);
  }

  /// Portfolio snapshot PDF.
  static Future<Uint8List> buildPortfolioPdf({
    required String investorName,
    required String investorCode,
    required double portfolioValue,
    required double totalCost,
    required double unrealizedGain,
    required List<ExportHoldingRow> holdings,
    required List<ExportDistributionRow> distributions,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'HD Homes — Investor Portfolio Report',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '$investorName · $investorCode · ${_date.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(height: 16),
          ],
        ),
        build: (context) => [
          pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Portfolio value', _currency.format(portfolioValue)],
              ['Capital invested', _currency.format(totalCost)],
              ['Unrealized gain', _currency.format(unrealizedGain)],
              ['Holdings', '${holdings.length}'],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Holdings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (holdings.isEmpty)
            pw.Text('No holdings')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Investment', 'Cost', 'Value', 'ROI'],
              data: holdings
                  .map(
                    (h) => [
                      h.label,
                      _currency.format(h.costBasis),
                      _currency.format(h.currentValue),
                      '${h.roiPct.toStringAsFixed(1)}%',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Recent distributions',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (distributions.isEmpty)
            pw.Text('No distributions')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Type', 'Status', 'Amount', 'Date'],
              data: distributions
                  .map(
                    (d) => [
                      d.type,
                      d.status,
                      _currency.format(d.amount),
                      d.date != null ? _date.format(d.date!) : '—',
                    ],
                  )
                  .toList(),
            ),
        ],
        footer: (context) => pw.Text(
          'Generated by HD Homes Investor Portal · Page ${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    );
    return doc.save();
  }

  static Uint8List buildPortfolioExcel({
    required String investorName,
    required String investorCode,
    required List<ExportHoldingRow> holdings,
    required List<ExportDistributionRow> distributions,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');
    final summary = excel['Summary'];
    summary.appendRow([
      TextCellValue('HD Homes Investor Report'),
    ]);
    summary.appendRow([TextCellValue(investorName), TextCellValue(investorCode)]);
    summary.appendRow([TextCellValue('Generated'), TextCellValue(_date.format(DateTime.now()))]);

    final holdingsSheet = excel['Holdings'];
    holdingsSheet.appendRow([
      TextCellValue('Investment'),
      TextCellValue('Cost'),
      TextCellValue('Value'),
      TextCellValue('ROI %'),
      TextCellValue('Units'),
    ]);
    for (final h in holdings) {
      holdingsSheet.appendRow([
        TextCellValue(h.label),
        DoubleCellValue(h.costBasis),
        DoubleCellValue(h.currentValue),
        DoubleCellValue(h.roiPct),
        DoubleCellValue(h.units),
      ]);
    }

    final distSheet = excel['Distributions'];
    distSheet.appendRow([
      TextCellValue('Type'),
      TextCellValue('Status'),
      TextCellValue('Amount'),
      TextCellValue('Date'),
    ]);
    for (final d in distributions) {
      distSheet.appendRow([
        TextCellValue(d.type),
        TextCellValue(d.status),
        DoubleCellValue(d.amount),
        TextCellValue(d.date != null ? _date.format(d.date!) : ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Excel workbook');
    }
    return Uint8List.fromList(bytes);
  }

  static String buildPortfolioCsv({
    required List<ExportHoldingRow> holdings,
  }) {
    final buf = StringBuffer('Investment,Cost,Value,ROI %,Units\n');
    for (final h in holdings) {
      buf.writeln(
        '"${h.label.replaceAll('"', '""')}",${h.costBasis},${h.currentValue},${h.roiPct},${h.units}',
      );
    }
    return buf.toString();
  }
}

class ExportHoldingRow {
  const ExportHoldingRow({
    required this.label,
    required this.costBasis,
    required this.currentValue,
    required this.roiPct,
    this.units = 0,
  });

  final String label;
  final double costBasis;
  final double currentValue;
  final double roiPct;
  final double units;
}

class ExportDistributionRow {
  const ExportDistributionRow({
    required this.type,
    required this.status,
    required this.amount,
    this.date,
  });

  final String type;
  final String status;
  final double amount;
  final DateTime? date;
}
