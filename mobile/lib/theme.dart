// ── ElForma · theme.dart ──
// Central design tokens: AppColors palette + shared ThemeData. Single source for styling.
// مصدر الألوان والثيم الموحد — لا تكتب ألوانا ثابتة خارجه.

import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF070B14);
  static const bg2 = Color(0xFF0B1220);
  static const card = Color(0xFF0E1626);
  static const card2 = Color(0xFF0B1220);
  static const line = Color(0x1AFFFFFF);
  static const text = Color(0xFFEAF2F7);
  static const muted = Color(0xFF8496AB);
  // nutrition (teal) + workout (orange) brand accents
  static const nu = Color(0xFF00D4AA);
  static const nu2 = Color(0xFF37E6C2);
  static const wo = Color(0xFFFF6B35);
  static const wo2 = Color(0xFFFF8F5E);

  // ── امتدادات Design v2 (2026) ──
  // الرموز دي كانت مستخدمة في الشاشات الجديدة بدون تعريف، فكانت بتكسّر
  // فحص الكود في CI. كلها const عشان تشتغل جوا سياقات const.
  /// خط أفخف من line — للحدود الهادية والفواصل ومسارات التقدم.
  static const lineSoft = Color(0x12FFFFFF);
  /// نص داكن فوق تدرج nu التركوازي (نفس الحبر المستخدم على الأزرار الملونة).
  static const onNu = Color(0xFF0A0F14);
  /// تركوازي أعمق — نقطة بداية التدرجات مع nu2.
  static const nuDeep = Color(0xFF00A383);
  /// نجاح / حالة إيجابية.
  static const good = Color(0xFF4ADE80);
  /// تحذير — أصفر كهرماني مميّز عن wo البرتقالي.
  static const warn = Color(0xFFFBBF24);
  /// خطأ / حالة خطر.
  static const danger = Color(0xFFFF6B6B);
  /// أزرق سماوي — كارت المياه والمعلومات.
  static const sky = Color(0xFF38BDF8);
  /// أخفت من muted — نصوص ثانوية جدًا.
  static const faint = Color(0xFF617187);
}

// ── Design tokens المشتركة لنظام 2026 ──
// نفس فكرة AppColors: مصدر واحد للحواف والمسافات والحركة والديكورات.

/// أنصاف أقطار الحواف الموحدة.
class EFR {
  EFR._();
  /// الشرائح السفلية وشريط التبويبات العائم.
  static const sheet = 24.0;
  /// الشرائح ومبدّلات الأنماط (segmented).
  static const chip = 12.0;
  /// عناصر التحكم: أزرار وحقول إدخال.
  static const control = 16.0;
  /// الكروت القياسية.
  static const card = 20.0;
}

/// مسافات الحشو الموحدة.
class EFS {
  EFS._();
  /// حشو الكروت الصغيرة.
  static const l = 16.0;
  /// حشو الكروت الكبيرة / الـ hero.
  static const xl = 20.0;
}

/// رموز الحركة: مدد + المنحنى القياسي.
class EFM {
  EFM._();
  /// تبديلات سريعة (مبدّلات، ضغطات).
  static const fast = Duration(milliseconds: 160);
  /// حركات متوسطة (الحبة المنزلقة في شريط التبويبات).
  static const med = Duration(milliseconds: 300);
  /// المنحنى القياسي لكل الحركات القصيرة.
  static const Curve curve = Curves.easeOutCubic;
}

/// قوالب الديكور الموحدة للكروت.
class EFDeco {
  EFDeco._();

  /// الكارت القياسي: خلفية card + حد lineSoft + حواف EFR.card.
  static BoxDecoration card() => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(EFR.card),
        border: Border.all(color: AppColors.lineSoft),
      );

  /// كارت بلون مميز: صبغة خفيفة من اللون + حد من نفس اللون.
  static BoxDecoration accentCard(Color color) => BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(EFR.card),
        border: Border.all(color: color.withValues(alpha: .25)),
      );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.nu,
      secondary: AppColors.wo,
      surface: AppColors.card,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card2,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.nu, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.nu.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
