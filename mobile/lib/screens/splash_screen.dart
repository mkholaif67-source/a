// ── ElForma · screens/splash_screen.dart ──
// Launch Experience v2 (2026): اللوجو نفسه هو بطل الافتتاحية.
//
// اللوجو الحقيقي اتفصل لـ 5 طبقات شفافة (قوس / لاعب / كلمة / ورقة / معيّنات)
// بنفس الـ canvas الأصلي — فبتركب pixel-perfect بدون إعادة رسم ولا تشويه.
// الافتتاحية: الطبقات بتتجمع بتتابع هادئ → جملة البراند بتنكشف → خط تقدم
// أفقي رفيع مربوط بمراحل الإقلاع الحقيقية (مش timer وهمي) → انتقال ناعم.
//
// ⚠️ كل منطق الإقلاع (_boot) محفوظ حرفيًا: warmup / init / UpdateGate / me /
// retries / maintenance / forced-update / ProfileStore warm. التغيير عرض فقط.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../models/profile_store.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import 'auth_screen.dart';
import 'shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // ── المتحكمات الحركية ──
  // _assemble: timeline واحد (1500ms) بيشغّل دخول الطبقات + الجملة + خط التقدم.
  // _idle: تنفّس هادئ جدًا بعد الاستقرار + بيشغّل ملاحقة التقدم كل فريم.
  late final AnimationController _assemble;
  late final AnimationController _idle;

  late final Animation<double> _arcIn;
  late final Animation<double> _figIn;
  late final Animation<double> _wordIn;
  late final Animation<double> _leafIn;
  late final Animation<double> _gemIn;
  late final Animation<double> _glowIn;
  late final Animation<double> _tagIn;
  late final Animation<double> _barIn;

  @override
  void initState() {
    super.initState();
    _assemble = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

    Animation<double> seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
        CurvedAnimation(parent: _assemble, curve: Interval(a, b, curve: c));
    _arcIn = seg(0.00, 0.36);
    _figIn = seg(0.12, 0.50);
    _wordIn = seg(0.28, 0.64);
    _leafIn = seg(0.44, 0.80);
    _gemIn = seg(0.62, 0.92, Curves.easeOutBack);
    _glowIn = seg(0.30, 1.00, Curves.easeOut);
    _tagIn = seg(0.55, 0.95);
    _barIn = seg(0.78, 1.00, Curves.easeOut);

    // ملاحقة التقدم بتتنداه من فريمات _idle المستمرة — صفر تكلفة إضافية.
    _idle.addListener(_chaseProgress);

    _assemble.forward();
    // التنفس يبدأ بعد ما التجمع يخلص عشان الافتتاح تبان متكامل مرة واحدة.
    _assemble.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_idle.isAnimating) {
        _idle.repeat(reverse: true);
      }
    });

    _boot();
  }

  // ────────────────────────────────────────────────────────────────
  //  BOOT LOGIC — محفوظ كما هو حرفيًا (الاتصال، الجلسة، التوجيه).
  //  ممنوع تتغير السلوكيات هنا؛ أي تعديل عرضي بس.
  // ────────────────────────────────────────────────────────────────
  String? _bootError;
  bool _bootOffline = false;
  bool _booting = false;
  int _bootAttempts = 0; // [BOOT-RETRY] عداد المحاولات الصامتة قبل إظهار أي رسالة
  Timer? _statusTimer;
  String? _bootStatus;
  int _bootPhase = 0;

  // مؤشر نسبة حقيقي مربوط بمراحل الإقلاع الفعلية (مش timer ثابت):
  // بيتقدم عند كل مرحلة حقيقية (قراءة الجلسة، رد السيرفر، تجهيز البيانات)،
  // وبين مرحلة والتانية بيزحف ببطء لحد سقف المرحلة بس — فمابيسبقش الحالة
  // الفعلية ومابيتأخرش عنها، ومابيلامس 100% إلا لحظة الانتقال.
  double _progressTarget = 0.0;
  double _progressCeiling = 0.0;
  double _shownProgress = 0.0;
  Timer? _creepTimer;
  Completer<void>? _settleCompleter;

  void _chaseProgress() {
    final d = _progressTarget - _shownProgress;
    if (d.abs() < 0.0004) {
      _shownProgress = _progressTarget;
    } else {
      _shownProgress += d * 0.075;
    }
    // نبضة الاستقرار: لما الخط يوصل بصريًا لآخره بنقفل الانتظار (لو فيه).
    final c = _settleCompleter;
    if (c != null && !c.isCompleted && _shownProgress >= 0.985) c.complete();
  }

  void _startProgressCreep() {
    _creepTimer?.cancel();
    _creepTimer = Timer.periodic(const Duration(milliseconds: 240), (_) {
      if (!mounted || _bootError != null) return;
      if (_progressTarget >= _progressCeiling) return;
      _progressTarget = (_progressTarget + 0.005).clamp(0.0, _progressCeiling);
    });
  }

  void _markProgress(double target, double ceiling) {
    if (target > _progressTarget) _progressTarget = target;
    final safeCeiling = ceiling < _progressTarget ? _progressTarget : ceiling;
    if (safeCeiling > _progressCeiling) _progressCeiling = safeCeiling;
  }

  /// انتظار قصير مسقوف (~600ms) عشان خط التقدم «يكتمل بصريًا» قبل الانتقال.
  /// لو الإقلاع كان بطيء أصلًا الخط بيكون وصل، فالانتظار بيكون صفر فعليًا.
  Future<void> _settleProgress() {
    if (_shownProgress >= 0.985) return Future<void>.value();
    final done = Completer<void>();
    _settleCompleter = done;
    return done.future.timeout(const Duration(milliseconds: 600), onTimeout: () {});
  }

  void _armBootStatus() {
    _statusTimer?.cancel();
    _bootPhase = 0;
    _bootStatus = null;
    // النص الوحيد المتبقي بيظهر بس لو الإقلاع البارد طول فعلًا (السيرفر بيصحى
    // من السكون)، بصياغة هادية بتفسّر الانتظار بصدق.
    _statusTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || _bootError != null) return;
      setState(() {
        _bootPhase = 2;
        _bootStatus = 'لسه بنجهز التطبيق — أول فتحة ممكن تاخد لحد دقيقة';
      });
    });
  }

  Future<void> _retryBoot() {
    _bootAttempts = 0; // [BOOT-RETRY] المحاولة اليدوية بتبدأ العدّ من الصفر
    setState(() { _bootError = null; });
    return _boot();
  }

  /// انتقال نهائي سلس: crossfade هادئ بدل القطع الجاف لأي شاشة جاية.
  PageRoute<void> _softRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: child,
      ),
    );
  }

  Future<void> _boot() async {
    if (_booting) return;
    _booting = true;
    // أول حاجة خالص: نوقظ السيرفر فورًا بالتوازي مع قراءة التخزين المحلي.
    unawaited(Api.I.warmup());
    _armBootStatus();
    _startProgressCreep();
    _markProgress(0.08, 0.18); // المرحلة 1: قراءة الجلسة من التخزين المحلي
    try {
      await Api.I.init();
      _markProgress(0.22, 0.55); // المرحلة 2: الجلسة اتقرت — السيرفر لسه بيرد

      /* Release gate first. If this build has been retired on the server we stop
         here instead of letting someone keep writing data with a version we know
         is broken. */
      const bootTimeout = Duration(seconds: 12);
      final checks = await Future.wait<dynamic>([
        UpdateGate.check(timeout: bootTimeout),
        Api.I.me(timeout: bootTimeout),
      ]);
      final gate = checks[0] as UpdateGate;
      final res = checks[1] as ApiResult;
      // التقدم بيقفز بس لما يكون فيه رد حقيقي من السيرفر (نجاح أو 401).
      if (res.ok || res.status == 401) {
        _markProgress(0.62, 0.80); // المرحلة 3: السيرفر رد فعليًا
      }

      /* Maintenance is checked before the update gate: an update sends you to
         the store, maintenance just asks you to wait — two different dead ends. */
      if (gate.maintenance) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(_softRoute(_MaintenanceScreen(gate: gate)));
        return;
      }

      if (gate.verdict == UpdateVerdict.required) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(_softRoute(_ForcedUpdateScreen(gate: gate)));
        return;
      }

      /* Distinguish "cannot reach the server" from "not signed in". A 401 is a
         real answer; a dead connection (0/5xx/timeout) must never be shown as
         a logout. */
      if (!res.ok && (res.status == 0 || res.status == 408 || res.status == 429 || res.status == 409 || res.status >= 500)) {
        if (!mounted) return;
        // السيرفر المجاني بياخد لحد دقيقة يصحى — التطبيق بيحاول لوحده بهدوء
        // (5 محاولات بفواصل متزايدة) قبل ما يظهر أي رسالة خطأ.
        if (_bootAttempts < 5 && (res.status == 0 || res.status == 408 || res.status >= 500)) {
          _bootAttempts++;
          const delays = [3, 4, 6, 8, 10];
          Timer(Duration(seconds: delays[_bootAttempts - 1]), () { if (mounted) _boot(); });
          return;
        }
        setState(() {
          _bootOffline = efIsOffline(res.status);
          _bootError = (res.status == 0 || res.status == 408)
              ? 'هناك مشكلة في الاتصال بالخادم. حاول مرة أخرى.'
              : efErrorMessage(res.status, res.data);
        });
        return;
      }

      final user = res.data['user'];
      // Warm the single source of truth while the animation plays, so the
      // workout and diet tabs open straight onto results with no flicker.
      if (user != null) {
        unawaited(ProfileStore.I.ensureLoaded(force: true));
      }
      // المرحلة الأخيرة: كل حاجة جاهزة — الخط بيكمّل لـ 100% لحظة الانتقال.
      _markProgress(1.0, 1.0);
      _creepTimer?.cancel();
      await _settleProgress(); // نبضة إكمال بصرية مسقوفة — مش انتظار مجاني
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _softRoute(user != null ? const ShellScreen() : const AuthScreen()),
      );
    } catch (_) {
      if (mounted) setState(() => _bootError = 'تعذر فتح التطبيق الآن. حاول مرة أخرى دون حذف بيانات التطبيق.');
    } finally {
      _booting = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _creepTimer?.cancel();
    _assemble.dispose();
    _idle.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  //  PRESENTATION — التجربة الافتتاحية الجديدة
  // ────────────────────────────────────────────────────────────────

  // موضع مركز اللوجو على الشاشة (نقطة واحدة يقرأها الـ glow والطبقات).
  static const Alignment _markCentre = Alignment(0, -0.20);
  static const double _markW = 232;
  static const double _markH = _markW * 300 / 325; // نفس نسبة اللوجو الأصلي

  /// طبقة لوجو متحركة: full-canvas شفافة بتدخل بـ fade + انزلاق/مقياس خفيف.
  Widget _layer(
    String asset,
    Animation<double> t, {
    Offset from = Offset.zero,
    double fromScale = 1.0,
  }) {
    final v = t.value;
    return Positioned.fill(
      child: Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(from.dx * (1 - v) * 60, from.dy * (1 - v) * 60),
          child: Transform.scale(
            scale: fromScale + (1 - fromScale) * v,
            child: Image.asset(asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootError != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: ErrorView(
          message: _bootError!,
          offline: _bootOffline,
          onRetry: _retryBoot,
        ),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_assemble, _idle]),
        builder: (context, _) {
          // تنفس هادئ جدًا بعد الاستقرار (سعة صغيرة عشان ميبقاش مزعج).
          final breath = Curves.easeInOut.transform(_idle.value);
          final glowPulse = 0.16 + breath * 0.08; // 0.16 ↔ 0.24
          final markScale = 1.0 + breath * 0.012; // 1.00 ↔ 1.012

          return Container(
            // خلفية مصمتة بلون AppColors.bg — نفس لون الـ native splash بالظبط،
            // فالانتقال native → Flutter بيكون غير مرئي (شاشة واحدة ممتدة).
            // العمق البصري بييجي من الـ glow المتحرك خلف اللوجو مش من gradient ثابت.
            decoration: const BoxDecoration(color: AppColors.bg),
            child: Stack(
              children: [
                // هالة براند هادية خلف اللوجو (مش glow مبالغ فيه).
                Align(
                  alignment: _markCentre,
                  child: Opacity(
                    opacity: _glowIn.value,
                    child: Container(
                      width: _markW * 1.5,
                      height: _markW * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.nu.withValues(alpha: glowPulse),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),

                // اللوجو المُجمَّع من طبقاته الحقيقية + تنفس نهائي خفيف.
                Align(
                  alignment: _markCentre,
                  child: Transform.scale(
                    scale: markScale,
                    child: SizedBox(
                      width: _markW,
                      height: _markH,
                      child: Stack(
                        children: [
                          _layer('assets/brand/logo_leaf.png', _leafIn,
                              from: const Offset(0.35, 0.45)),
                          _layer('assets/brand/logo_arc.png', _arcIn,
                              from: const Offset(0, -0.55)),
                          _layer('assets/brand/logo_figure.png', _figIn,
                              from: const Offset(0, -0.18), fromScale: 0.92),
                          _layer('assets/brand/logo_word.png', _wordIn,
                              from: const Offset(0, 0.42)),
                          _layer('assets/brand/logo_gem.png', _gemIn,
                              fromScale: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),

                // جملة البراند — بتنكشف بنعومة مع استقرار اللوجو.
                Align(
                  alignment: const Alignment(0, 0.13),
                  child: Opacity(
                    opacity: _tagIn.value,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - _tagIn.value)),
                      child: const Text(
                        'تغذية • تمرين • صحة أفضل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),

                // مؤشر التقدم الأفقي — مربوط بمراحل الإقلاع الحقيقية.
                Align(
                  alignment: const Alignment(0, 0.44),
                  child: Opacity(
                    opacity: _barIn.value,
                    child: Container(
                      width: 172,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lineSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: _shownProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.nuDeep, AppColors.nu2],
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // رسالة صادقة تظهر فقط لو الإقلاع البارد طول (السيرفر بيصحى).
                Align(
                  alignment: const Alignment(0, 0.56),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _bootStatus == null
                        ? const SizedBox.shrink()
                        : Padding(
                            key: ValueKey<int>(_bootPhase),
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _bootStatus!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.faint,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.6),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown while the admin has the app switched off from the dashboard. Unlike
/// the forced-update screen this is a TEMPORARY dead end, so the single action
/// it offers is a fresh boot.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.gate});
  final UpdateGate gate;

  @override
  Widget build(BuildContext context) {
    final title =
        gate.maintenanceTitle.trim().isEmpty ? 'صيانة مؤقتة' : gate.maintenanceTitle.trim();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.wo.withValues(alpha: 0.12),
                    border: Border.all(
                        color: AppColors.wo.withValues(alpha: 0.40), width: 1.4),
                  ),
                  child: const Icon(Icons.build_circle_rounded,
                      color: AppColors.wo, size: 46),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                    ),
                    child: const Text('جرب تاني'),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'بياناتك واشتراكك محفوظين زي ما هما',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown ONLY when the server has retired this build. There is deliberately no
/// way past it: a release we know is broken stops writing data. Dead end by
/// design, so it must explain itself clearly and hand one obvious action.
class _ForcedUpdateScreen extends StatelessWidget {
  const _ForcedUpdateScreen({required this.gate});
  final UpdateGate gate;

  Future<void> _openStore(BuildContext context) async {
    final url = gate.storeUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المتجر حدث التطبيق يدويا')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.wo.withValues(alpha: 0.12),
                    border: Border.all(
                        color: AppColors.wo.withValues(alpha: 0.40), width: 1.4),
                  ),
                  child: const Icon(Icons.system_update_rounded,
                      color: AppColors.wo, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'محتاج تحديث',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 28),
                if (gate.storeUrl.trim().isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _openStore(context),
                      child: const Text('حدث دلوقتي'),
                    ),
                  )
                else
                  const Text(
                    'حدث التطبيق من المتجر وافتحه تاني',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                  ),
                const SizedBox(height: 18),
                Text(
                  'نسختك الحالية: $kAppBuild',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
