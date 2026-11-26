import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/common.dart';
import '../widgets/signature_pad.dart';

/// Tamper-evident seal: both parties sign the move-in evidence, and the
/// SHA-256 fingerprint proves later that nothing was edited.
class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key});

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  final _verify = TextEditingController();
  bool? _match;

  @override
  void dispose() {
    _verify.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tenancy!;
    final current = fingerprintOf(t);

    return PageFrame(
      title: 'Evidence seal',
      subtitle: 'Both parties sign · any later edit to move-in evidence breaks the seal',
      children: [
        SealBanner(sealed: t.isSealed, intact: t.sealIntact),
        ResponsiveGrid(maxColumns: 2, children: [
          _signerCard(context, 'tenant', t.tenant),
          _signerCard(context, 'landlord', t.landlord),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.fingerprint, color: Color(0xFF15803D)),
                SizedBox(width: 8),
                Text('SHA-256 fingerprint', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              SelectableText(t.sealedFingerprint ?? current,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: t.sealedFingerprint ?? current));
                  toast(context, 'Fingerprint copied: share it with the other party');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy to share'),
              ),
              const Divider(height: 32),
              const Text('Verify a fingerprint someone sent you',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _verify,
                    decoration: const InputDecoration(
                        isDense: true, hintText: 'Paste 64-character fingerprint'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => setState(() =>
                      _match = _verify.text.trim().toLowerCase() == current),
                  child: const Text('Verify'),
                ),
              ]),
              if (_match != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _match!
                        ? '✓ Matches: this is exactly the evidence that was signed.'
                        : '✗ Does not match the current evidence.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _match! ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _signerCard(BuildContext context, String role, String name) {
    final s = AppScope.of(context);
    final sig = s.tenancy!.signatures.where((x) => x.role == role).firstOrNull;
    final mine = s.role.name == role;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(sig == null
                    ? '${role[0].toUpperCase()}${role.substring(1)} · not signed'
                    : '${role[0].toUpperCase()}${role.substring(1)} · signed ${dateTimeFmt.format(sig.at)}'),
              ]),
            ),
            Icon(sig == null ? Icons.pending_outlined : Icons.verified,
                color: sig == null ? Colors.orange.shade800 : const Color(0xFF15803D)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: sig == null
                ? null
                : CustomPaint(
                    painter: StrokePainter.fromPoints(
                        _fit(sig.strokes, 60), Theme.of(context).colorScheme.onSurface)),
          ),
          if (sig == null || mine)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: mine
                    ? () => _signDialog(context, role, name)
                    : () => toast(context, 'Switch role in Settings to sign as $role'),
                icon: const Icon(Icons.draw),
                label: Text(sig == null ? 'Sign now' : 'Re-sign'),
              ),
            ),
        ]),
      ),
    );
  }

  /// Scales a stored signature to fit a preview box of [h] pixels.
  List<List<List<double>>> _fit(List<List<List<double>>> strokes, double h) {
    double maxY = 1;
    for (final s in strokes) {
      for (final p in s) {
        if (p[1] > maxY) maxY = p[1];
      }
    }
    final k = h / (maxY + 4);
    return [
      for (final s in strokes) [for (final p in s) [p[0] * k, p[1] * k]]
    ];
  }

  Future<void> _signDialog(BuildContext context, String role, String name) async {
    final s = AppScope.of(context);
    var strokes = <List<List<double>>>[];
    var agreed = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Sign as $name'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SignaturePad(onChanged: (v) => setD(() => strokes = v)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agreed,
                onChanged: (v) => setD(() => agreed = v ?? false),
                title: const Text(
                    'I confirm the move-in checklist and photos reflect the actual condition of the property.'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: agreed && strokes.isNotEmpty ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Sign'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      s.sign(Signature(name: name, role: role, at: DateTime.now(), strokes: strokes));
      if (context.mounted) {
        toast(context, s.tenancy!.isSealed ? 'Both signed: evidence sealed 🔒' : 'Signed. Waiting for the other party.');
      }
    }
  }
}
