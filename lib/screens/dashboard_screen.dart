import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tenancy!;
    final months = t.monthsAt(s.now);
    final damage = s.engine.damage(t.items, months);
    final deduction = damage + t.totalDues;
    final refund = t.deposit - deduction;
    final photos = t.items.fold<int>(0, (n, i) => n + i.photos.length);
    final inspected = t.items.where((i) => i.moveOut != null).length;
    final me = s.role == Role.tenant ? t.tenant : t.landlord;

    // Next best action for whoever is using the app.
    final (String nextText, int nextPage) = !t.isSealed
        ? (photos == 0
            ? ('Add move-in photos for each item', 1)
            : ('Sign the move-in evidence to seal it', 4))
        : inspected < t.items.length
            ? ('Record move-out condition (${t.items.length - inspected} left)', 2)
            : ('Send the settlement report', 2);

    return PageFrame(
      title: 'Namaste, ${me.split(' ').first} 👋',
      subtitle: '${t.address} · viewing as ${s.role.name}',
      action: FilledButton.icon(
        onPressed: () => onNavigate(nextPage),
        icon: const Icon(Icons.arrow_forward),
        label: Text(nextText),
      ),
      children: [
        SealBanner(sealed: t.isSealed, intact: t.sealIntact),
        _HeroCard(deposit: t.deposit, refund: refund, deduction: deduction),
        const SizedBox(height: 16),
        ResponsiveGrid(children: [
          StatCard(
              label: 'Evidence items',
              value: '${t.items.length}',
              icon: Icons.fact_check,
              footnote: '$photos hashed photos'),
          StatCard(
              label: 'Tenancy',
              value: '$months months',
              icon: Icons.calendar_month,
              color: const Color(0xFF6D28D9),
              footnote: '${s.engine.wearAllowance(months)} level wear & tear allowed'),
          StatCard(
              label: 'Rent paid',
              value: inr(t.paidRent),
              icon: Icons.receipt_long,
              color: const Color(0xFF0E7490),
              footnote: t.unpaidRent == 0 ? 'All clear' : '${inr(t.unpaidRent)} pending'),
          StatCard(
              label: 'Move-out check',
              value: '$inspected / ${t.items.length}',
              icon: Icons.compare,
              color: const Color(0xFFB45309),
              footnote: 'items inspected'),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How DepositGuard protects both sides',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                for (final (icon, text) in [
                  (Icons.photo_camera, 'Room-by-room move-in photos, each with a SHA-256 hash'),
                  (Icons.draw, 'Tenant and landlord sign → the evidence is sealed'),
                  (Icons.balance, 'Fair rules: normal wear & tear is never charged'),
                  (Icons.picture_as_pdf, 'One-tap settlement report and HRA rent receipts'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.deposit, required this.refund, required this.deduction});
  final int deposit, refund, deduction;

  @override
  Widget build(BuildContext context) {
    final share = deposit == 0 ? 0.0 : (refund / deposit).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF115E59)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security deposit protected', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(inr(deposit),
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: const Color(0xFF5EEAD4),
            ),
          ),
          const SizedBox(height: 10),
          Text('Estimated refund ${inr(refund)}  ·  fair deductions ${inr(deduction)}',
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
