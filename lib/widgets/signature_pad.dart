import 'package:flutter/material.dart';

/// Finger / mouse / stylus signature pad. Returns strokes as [x, y] points.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged, this.height = 180});
  final ValueChanged<List<List<List<double>>>> onChanged;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];

  void _emit() => widget.onChanged([
        for (final s in _strokes) [for (final p in s) [p.dx, p.dy]]
      ]);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              onPanEnd: (_) => _emit(),
              child: CustomPaint(
                painter: StrokePainter(_strokes, scheme.onSurface),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            setState(_strokes.clear);
            _emit();
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Clear'),
        ),
      ],
    );
  }
}

class StrokePainter extends CustomPainter {
  StrokePainter(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;

  /// Helper for redrawing saved signatures.
  factory StrokePainter.fromPoints(List<List<List<double>>> pts, Color color) =>
      StrokePainter([
        for (final s in pts) [for (final p in s) Offset(p[0], p[1])]
      ], color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.3, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) => true;
}
