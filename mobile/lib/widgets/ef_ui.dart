// ── ElForma · widgets/ef_ui.dart ──
// Shared micro-interactions for the 2026 design system.
// مكونات حركة صغيرة مشتركة: ضغطة بنبضة، وظهور متدرج هادئ للأقسام.
// كلها Presentation فقط — مفيش أي Logic هنا.

import 'package:flutter/material.dart';
import '../theme.dart';

/// غلاف ضغطة: scale خفيف جدًا عند اللمس (0.975) ويرجع بمرونة.
/// بيدي إحساس المنتج الحي بدون أي تأثير مبالغ فيه.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _s = Tween<double>(begin: 1, end: 0.972)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _c.forward() : null,
      onTapCancel: active ? () => _c.reverse() : null,
      onTapUp: active ? (_) => _c.reverse() : null,
      onTap: active ? widget.onTap : null,
      child: ScaleTransition(scale: _s, child: widget.child),
    );
  }
}

/// ظهور متدرج: fade + rise بسيط، بيتأخر حسب [order].
/// بيشتغل مرة واحدة عند أول build — مفيش إعادة تشغيل مع كل setState.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.order = 0, this.dy = 16});

  final Widget child;

  /// ترتيب الظهور (0 يظهر أول). التأخير = order × 60ms وسقفه 420ms.
  final int order;
  final double dy;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.order * 60).clamp(0, 420);
    const runMs = 480;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: delayMs + runMs));
    final curve = Interval(
      delayMs / (delayMs + runMs),
      1,
      curve: EFM.curve,
    );
    _fade = CurvedAnimation(parent: _c, curve: curve);
    _slide = Tween<Offset>(begin: Offset(0, widget.dy / 100), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: curve));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// عنوان قسم صغير موحد (eyebrow) بلون مميز.
class EFEyebrow extends StatelessWidget {
  const EFEyebrow(this.text, {super.key, this.color = AppColors.nu});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .2),
        ),
      ],
    );
  }
}
