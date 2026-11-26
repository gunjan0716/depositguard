import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';

// The built-in PDF font has no ₹ glyph, so reports use "Rs.".
final _rs = NumberFormat.decimalPattern('en_IN');
String rs(num v) => 'Rs. ${_rs.format(v)}';
final _d = DateFormat('d MMM yyyy, h:mm a');

/// Settlement report: evidence, item-by-item deductions, refund, seal.
Future<Uint8List> settlementPdf(Tenancy t, DeductionEngine engine, DateTime now) async {
  final months = t.monthsAt(now);
  final rows = engine.evaluateAll(t.items, months);
  final damage = rows.fold<int>(0, (s, r) => s + r.amount);
  final refund = t.deposit - damage - t.totalDues;
  final doc = pw.Document(title: 'DepositGuard settlement', author: 'DepositGuard');

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => [
      pw.Text('Security deposit settlement',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(t.address),
      pw.Text('Tenant: ${t.tenant}    Landlord: ${t.landlord}'),
      pw.Text('Tenancy: ${DateFormat('d MMM yyyy').format(t.start)} to '
          '${DateFormat('d MMM yyyy').format(now)} ($months months). '
          'Wear & tear allowance: ${engine.wearAllowance(months)} level(s) per item.'),
      pw.SizedBox(height: 16),
      pw.TableHelper.fromTextArray(
        headers: ['Room', 'Item', 'Move-in', 'Move-out', 'Photos', 'Deduction', 'Reason'],
        data: [
          for (final r in rows)
            [
              r.item.room,
              r.item.name,
              r.item.moveIn.label,
              r.item.moveOut?.label ?? '-',
              '${r.item.photos.length}',
              rs(r.amount),
              r.reason.replaceAll('₹', 'Rs. ').replaceAll('→', '->'),
            ]
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
      ),
      pw.SizedBox(height: 16),
      _line('Security deposit', rs(t.deposit)),
      _line('Damage beyond wear & tear', '- ${rs(damage)}'),
      _line('Unpaid rent', '- ${rs(t.unpaidRent)}'),
      _line('Other agreed dues', '- ${rs(t.otherDues)}'),
      pw.Divider(),
      _line('Refund to tenant', rs(refund), bold: true),
      pw.SizedBox(height: 20),
      pw.Text('Evidence seal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      for (final s in t.signatures) pw.Text('${s.role}: ${s.name}, signed ${_d.format(s.at)}'),
      pw.Text('Sealed SHA-256: ${t.sealedFingerprint ?? 'not sealed'}',
          style: const pw.TextStyle(fontSize: 8)),
      pw.Text('Current SHA-256: ${fingerprintOf(t)}', style: const pw.TextStyle(fontSize: 8)),
      pw.Text(t.isSealed && t.sealIntact
          ? 'Seal intact: move-in evidence unchanged since signing.'
          : 'WARNING: seal missing or broken.'),
    ],
  ));
  return doc.save();
}

/// One HRA rent receipt per paid month.
Future<Uint8List> hraReceiptsPdf(Tenancy t) async {
  final doc = pw.Document(title: 'Rent receipts');
  for (final p in t.payments.where((p) => p.paid)) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RENT RECEIPT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Received ${rs(p.amount)} from ${t.tenant} towards rent for '
              '${DateFormat('MMMM yyyy').format(p.month)} for the property at ${t.address}.'),
          pw.SizedBox(height: 8),
          pw.Text('Paid on ${DateFormat('d MMM yyyy').format(p.paidOn!)} via ${p.mode}.'),
          pw.Spacer(),
          pw.Text('Landlord: ${t.landlord}'),
          pw.Text('Signature: ____________________'),
        ]),
      ),
    ));
  }
  return doc.save();
}

pw.Widget _line(String a, String b, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(a, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14) : null)),
        pw.Text(b, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14) : null),
      ]),
    );

/// Opens the system share / print / save dialog on every platform.
Future<void> sharePdf(Uint8List bytes, String filename) =>
    Printing.sharePdf(bytes: bytes, filename: filename);
