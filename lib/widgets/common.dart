import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String inr(num v) => _inr.format(v);
final dateFmt = DateFormat('d MMM yyyy');
final dateTimeFmt = DateFormat('d MMM yyyy, h:mm a');

Color conditionColor(Condition c) => switch (c) {
      Condition.good => const Color(0xFF15803D),
      Condition.fair => const Color(0xFF0E7490),
      Condition.worn => const Color(0xFFB45309),
      Condition.damaged => const Color(0xFFB91C1C),
    };

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

class ConditionChip extends StatelessWidget {
  const ConditionChip(this.condition, {super.key});
  final Condition? condition;

  @override
  Widget build(BuildContext context) {
    final c = condition;
    final color = c == null ? Colors.grey : conditionColor(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(c?.label ?? 'Pending',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Page scaffold with a title, subtitle and a max content width so it looks
/// right on a phone, a browser tab and a maximised Windows window.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: EdgeInsets.all(narrow ? 16 : 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                if (action != null && !narrow) action!,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
            if (action != null && narrow) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = const Color(0xFF0F766E),
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(footnote!, style: TextStyle(color: color, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lays children in 1, 2 or [maxColumns] columns depending on width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.maxColumns = 4});
  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 900
          ? maxColumns
          : box.maxWidth > 500
              ? 2
              : 1;
      const gap = 16.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    });
  }
}

/// "Sealed / Broken / Not sealed" banner reused on several screens.
class SealBanner extends StatelessWidget {
  const SealBanner({super.key, required this.sealed, required this.intact});
  final bool sealed;
  final bool intact;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String text) = !sealed
        ? (Colors.orange.shade800, Icons.lock_open,
            'Not sealed yet: both parties must sign the move-in evidence.')
        : intact
            ? (const Color(0xFF15803D), Icons.lock, 'Sealed & intact: move-in evidence is locked.')
            : (Colors.red.shade700, Icons.gpp_bad,
                'Seal broken: move-in evidence was changed after signing.');
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
