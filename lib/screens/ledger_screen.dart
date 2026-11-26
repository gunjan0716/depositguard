import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/report.dart';
import '../state.dart';
import '../widgets/common.dart';

/// Rent ledger: every payment becomes evidence and an HRA-ready receipt.
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tenancy!;
    final month = DateFormat('MMMM yyyy');
    final landlord = s.role == Role.landlord;

    return PageFrame(
      title: 'Rent ledger',
      subtitle: '${inr(t.paidRent)} paid · ${inr(t.unpaidRent)} pending',
      action: FilledButton.tonalIcon(
        onPressed: t.payments.any((p) => p.paid)
            ? () async => sharePdf(await hraReceiptsPdf(t), 'HRA-rent-receipts.pdf')
            : null,
        icon: const Icon(Icons.download),
        label: const Text('HRA receipts PDF'),
      ),
      children: [
        Card(
          child: Column(children: [
            if (t.payments.isEmpty)
              const ListTile(title: Text('No rent months yet')),
            for (final p in t.payments.reversed)
              ListTile(
                leading: Icon(
                  p.paid ? Icons.check_circle : Icons.schedule,
                  color: p.paid ? Colors.green.shade700 : Colors.orange.shade800,
                ),
                title: Text(month.format(p.month)),
                subtitle: Text(p.paid
                    ? 'Paid ${dateFmt.format(p.paidOn!)} via ${p.mode}'
                    : 'Due 5 ${DateFormat('MMM yyyy').format(p.month)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(inr(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  if (!p.paid)
                    TextButton(
                      onPressed: () => _markPaid(context, p),
                      child: Text(landlord ? 'Confirm received' : 'Mark paid'),
                    )
                  else
                    IconButton(
                      tooltip: 'Undo',
                      onPressed: () {
                        p.paidOn = null;
                        s.changed();
                      },
                      icon: const Icon(Icons.undo, size: 18),
                    ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: s.addMonthlyRent,
            icon: const Icon(Icons.add),
            label: const Text('Add next month'),
          ),
        ),
      ],
    );
  }

  Future<void> _markPaid(BuildContext context, RentPayment p) async {
    final s = AppScope.of(context);
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Paid via'),
        children: [
          for (final m in ['UPI', 'Bank transfer', 'Cash', 'Cheque'])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text(m)),
        ],
      ),
    );
    if (mode == null) return;
    p
      ..mode = mode
      ..paidOn = DateTime.now();
    s.changed();
  }
}
