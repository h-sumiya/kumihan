import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../engine/constants.dart';
import '../kumihan_theme.dart';

class KumihanDefaultBookDesk extends StatelessWidget {
  const KumihanDefaultBookDesk({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFB2875A), Color(0xFF7A5434)],
        ),
      ),
      child: CustomPaint(painter: const _DeskGrainPainter()),
    );
  }
}

class KumihanDefaultBlankBookPage extends StatelessWidget {
  const KumihanDefaultBlankBookPage({
    super.key,
    required this.title,
    required this.theme,
  });

  final String title;
  final KumihanThemeData theme;

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Untitled' : title.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.paperColor,
        border: Border.all(color: const Color(0xFFBDB7AA), width: 1.2),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.88),
                fontFamily: defaultMinchoFontFamilies.first,
                fontFamilyFallback: defaultMinchoFontFamilies.sublist(1),
                package: bundledFontPackage,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KumihanSinglePageEdgeOverlay extends StatelessWidget {
  const KumihanSinglePageEdgeOverlay({super.key, required this.edge});

  final Widget edge;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(left: 0, top: 0, child: KeyedSubtree.wrap(edge, 0)),
          Positioned(
            right: 0,
            top: 0,
            child: RotatedBox(
              quarterTurns: 1,
              child: KeyedSubtree.wrap(edge, 1),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: KeyedSubtree.wrap(edge, 2),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: RotatedBox(
              quarterTurns: 3,
              child: KeyedSubtree.wrap(edge, 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskGrainPainter extends CustomPainter {
  const _DeskGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1;
    final darkPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.2;

    for (var index = 0; index < 18; index += 1) {
      final dy = size.height * index / 18;
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy + math.min(12, size.height * 0.03)),
        lightPaint,
      );
      canvas.drawLine(Offset(0, dy + 6), Offset(size.width, dy + 2), darkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
