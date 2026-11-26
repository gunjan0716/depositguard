import 'package:flutter/material.dart';

import '../models.dart';
import '../services/report.dart';
import '../state.dart';
import '../widgets/common.dart';
import 'inspection_screen.dart' show capturePhoto;

/// Move-out comparison with explainable, rule-based deductions.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tenancy!;
    final months = t.monthsAt(s.now);
    final results = s.engine.evaluateAll(t.items, months);
    final damage = results.fold<int>(0, (n, r) => n + r.amount);
    final refund = t.deposit - damage - t.totalDues;
    final narrow = MediaQuery.sizeOf(context).width < 700;

    return PageFrame(
      title: 'Move-out comparison',
      subtitle: '$months-month tenancy · ${s.engine.wearAllowance(months)} level of wear & tear '
          'allowed per item · tap a status to set it',
      children: [
        if (!t.isSealed || !t.sealIntact) SealBanner(sealed: t.isSealed, intact: t.sealIntact),
        Card(
          child: Column(children: [
            for (final r in results)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(r.reason, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ]),
                  ),
                  if (!narrow) ...[
                    IconButton(
                      tooltip: 'Add move-out photo (${r.item.photosAt('move-out')})',
                      onPressed: () => capturePhoto(context, r.item, 'move-out'),
                      icon: Badge(
                        isLabelVisible: r.item.photosAt('move-out') > 0,
                        label: Text('${r.item.photosAt('move-out')}'),
                        child: const Icon(Icons.add_a_photo_outlined, size: 20),
                      ),
                    ),
                    ConditionChip(r.item.moveIn),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                  ],
                  PopupMenuButton<Condition>(
                    tooltip: 'Set move-out condition',
                    onSelected: (c) {
                      r.item.moveOut = c;
                      s.changed();
                    },
                    itemBuilder: (_) => [
                      for (final c in Condition.values) PopupMenuItem(value: c, child: Text(c.label)),
                    ],
                    child: ConditionChip(r.item.moveOut),
                  ),
                  SizedBox(
                    width: narrow ? 76 : 96,
                    child: Text(
                      r.amount == 0 ? '₹0' : '− ${inr(r.amount)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.amount == 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _row('Security deposit', inr(t.deposit)),
              _row('Damage beyond wear & tear', '− ${inr(damage)}'),
              _row('Unpaid rent', '− ${inr(t.unpaidRent)}'),
              Row(children: [
                const Expanded(child: Text('Other agreed dues (electricity, maintenance)')),
                TextButton(
                  onPressed: () => _editDues(context),
                  child: Text('− ${inr(t.otherDues)}  ✎'),
                ),
              ]),
              const Divider(height: 24),
              _row(refund >= 0 ? 'Refund to tenant' : 'Tenant owes landlord', inr(refund.abs()), bold: true),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final pdf = await settlementPdf(t, s.engine, s.now);
                      await sharePdf(pdf, 'DepositGuard-settlement.pdf');
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Share settlement PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      for (final i in t.items) {
                        i.moveOut = null;
                      }
                      s.changed();
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset move-out'),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _editDues(BuildContext context) async {
    final s = AppScope.of(context);
    final c = TextEditingController(text: '${s.tenancy!.otherDues}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Other agreed dues'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v >= 0) {
      s.tenancy!.otherDues = v;
      s.changed();
    }
  }

  Widget _row(String a, String b, {bool bold = false}) {
    final style = TextStyle(fontSize: bold ? 20 : 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(a, style: style)), Text(b, style: style)]),
    );
  }
}
