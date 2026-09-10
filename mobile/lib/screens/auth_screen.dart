// ── ElForma · screens/auth_screen.dart ──
// Login / Signup — Design v2 (2026). امتداد طبيعي للـ Launch Experience.
//
// ⚠️ كل المنطق محفوظ حرفيًا: نفس الـ controllers، نفس التحقق (_passwordProblem,
// phoneError/phoneNational)، نفس الاستدعاءات (login/signup/google/forgotPassword)،
// نفس الـ geo prefill (_loadGeo)، ونفس التوجيه لـ ShellScreen. التغيير عرض وUX فقط.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api.dart';
import '../theme.dart';
import '../country_codes.dart';
import '../widgets/ef_ui.dart';
import 'shell_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _login = true;
  bool _busy = false;
  bool _hide = true;
  bool _hide2 = true;
  String _countryIso = 'EG';
  String? _error;
  final _ident = TextEditingController(); // الدخول: بريد أو رقم
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  Country get _country =>
      kCountries.firstWhere((e) => e.iso == _countryIso, orElse: () => kCountries.first);

  @override
  void initState() {
    super.initState();
    _pass.addListener(_onPasswordChanged);
    _loadGeo();
  }

  void _onPasswordChanged() { if (mounted && !_login) setState(() {}); }

  Future<void> _loadGeo() async {
    try {
      final r = await Api.I.plans();
      if (!mounted || !r.ok) return;
      final geo = (r.data['geo'] as Map?)?.cast<String, dynamic>() ?? {};
      final iso = (geo['country']?.toString().toUpperCase() ?? '');
      if (iso.isNotEmpty && kCountries.any((c) => c.iso == iso)) {
        setState(() => _countryIso = iso);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ident.dispose();
    _email.dispose();
    _phone.dispose();
    _name.dispose();
    _pass.removeListener(_onPasswordChanged);
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _ident.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اكتب بريد حسابك وهنبعتلك رابط لتعيين كلمة مرور جديدة',
                style: TextStyle(color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'البريد الإلكتروني'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('ابعت الرابط'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    setState(() => _busy = true);
    await Api.I.forgotPassword(email);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لو البريد مسجل عندنا هتوصلك رسالة فيها رابط تعيين كلمة مرور جديدة خلال دقايق')));
  }

  // قاعدة أمان كلمة المرور (متوافقة مع السيرفر: 8 أحرف + حروف + أرقام).
  String? _passwordProblem(String pw) {
    if (pw.length < 8) return 'كلمة المرور لازم تكون 8 أحرف على الأقل';
    if (pw.length > 200) return 'كلمة المرور طويلة جدا';
    if (!RegExp(r'[A-Za-z]').hasMatch(pw)) return 'كلمة المرور لازم تحتوي على حروف وأرقام';
    if (!RegExp(r'[0-9]').hasMatch(pw)) return 'لازم تحتوي على رقم واحد على الأقل';
    return null;
  }

  Future<void> _submit() async {
    if (_login) {
      final identifier = _ident.text.trim();
      if (identifier.isEmpty) {
        setState(() => _error = 'اكتب البريد أو رقم الهاتف');
        return;
      }
      if (_pass.text.isEmpty) {
        setState(() => _error = 'اكتب كلمة المرور');
        return;
      }
      setState(() { _busy = true; _error = null; });
      final res = await Api.I.login(identifier, _pass.text);
      _afterAuth(res);
      return;
    }

    // إنشاء حساب
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'الاسم مطلوب');
      return;
    }
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'اكتب بريد إلكتروني صحيح');
      return;
    }
    // [OWNER-RULE] رقم الهاتف اختياري تماما.
    final c = _country;
    final phoneProblem = phoneError(c, _phone.text);
    if (phoneProblem != null) {
      setState(() => _error = phoneProblem);
      return;
    }
    final national = phoneNational(c, _phone.text);
    final pwProblem = _passwordProblem(_pass.text);
    if (pwProblem != null) {
      setState(() => _error = pwProblem);
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'تأكيد كلمة المرور مش مطابق');
      return;
    }

    setState(() { _busy = true; _error = null; });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': email,
      if (national.isNotEmpty) 'phone': '+${c.dial}$national',
      'password': _pass.text,
    };
    final res = await Api.I.signup(body);
    _afterAuth(res);
  }

  void _afterAuth(ApiResult res) {
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok && res.data['user'] != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    } else {
      setState(() => _error = res.friendlyError('حصل خطأ حاول تاني'));
    }
  }

  // دخول/تسجيل بحساب Google — نفس الآلية الحالية بالضبط.
  Future<void> _google() async {
    setState(() { _busy = true; _error = null; });
    try {
      const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
      final gsi = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: webClientId.isEmpty ? null : webClientId,
      );
      try { await gsi.signOut(); } catch (_) {}
      final acc = await gsi.signIn();
      if (acc == null) {
        if (mounted) setState(() => _busy = false);
        return; // المستخدم لغى
      }
      final authd = await acc.authentication;
      final idToken = authd.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) setState(() { _busy = false; _error = 'تعذر الدخول بجوجل، جرب تاني'; });
        return;
      }
      final res = await Api.I.googleAuth(idToken, name: acc.displayName, email: acc.email);
      _afterAuth(res);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'تعذر الدخول بجوجل — تأكد من إعداد جوجل لاحقا'; });
    }
  }

  void _switchMode(bool login) {
    if (_login == login) return;
    setState(() {
      _login = login;
      _error = null;
    });
  }

  void _pickCountry() {
    final search = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(EFR.sheet))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final q = search.text.trim().toLowerCase();
          final list = q.isEmpty
              ? kCountries
              : kCountries.where((c) => c.name.toLowerCase().contains(q) || c.iso.toLowerCase().contains(q) || c.dial.contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .72,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن الدولة أو الكود'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                        trailing: Text('+${c.dial}', style: TextStyle(color: c.iso == _countryIso ? AppColors.nu : AppColors.muted, fontWeight: FontWeight.w900)),
                        onTap: () {
                          setState(() => _countryIso = c.iso);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  PRESENTATION
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg2, AppColors.bg],
          ),
        ),
        child: Stack(
          children: [
            // هالة براند خفيفة جدًا فوق — نفس عائلة إضاءة الـ Splash.
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.nu.withValues(alpha: 0.10),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // اللوجو المُجمَّع (نفس أصل اللوجو الحقيقي) — امتداد الافتتاحية.
                              Reveal(
                                order: 0,
                                dy: 10,
                                child: Center(
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 88,
                                    height: 88 * 300 / 325,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Reveal(
                                order: 1,
                                child: Column(children: [
                                  Text(
                                    _login ? 'مرحبًا بك مجددًا' : 'إنشاء حساب',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.text, height: 1.2),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _login
                                        ? 'سجل دخولك لمتابعة رحلتك'
                                        : 'ابدأ رحلتك نحو أفضل نسخة منك',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 20),
                              Reveal(order: 2, child: _modeToggle()),
                              const SizedBox(height: 18),

                              Reveal(
                                order: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: _login ? _loginFields() : _signupFields(),
                                ),
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                _errorBox(),
                              ],

                              const SizedBox(height: 20),
                              Reveal(order: 4, child: _cta()),
                              const SizedBox(height: 18),
                              Reveal(order: 5, child: _orDivider()),
                              const SizedBox(height: 18),
                              Reveal(
                                order: 6,
                                child: _googleButton(_login ? 'تسجيل الدخول باستخدام Google' : 'إنشاء حساب باستخدام Google'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// مبدّل الوضع (دخول / حساب جديد) — نفس منطق _switchMode الحالي.
  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(EFR.chip),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(children: [
        _seg('تسجيل الدخول', _login, () => _switchMode(true)),
        _seg('إنشاء حساب', !_login, () => _switchMode(false)),
      ]),
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : onTap,
        child: AnimatedContainer(
          duration: EFM.fast,
          curve: EFM.curve,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [AppColors.nu, AppColors.nu2]) : null,
            borderRadius: BorderRadius.circular(EFR.chip),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.onNu : AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF9B9B), height: 1.5))),
      ]),
    );
  }

  // ── حقول تسجيل الدخول ──
  List<Widget> _loginFields() {
    return [
      _field(
        controller: _ident,
        hint: 'البريد الإلكتروني أو رقم الهاتف',
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      _passwordField(_pass, 'كلمة المرور', _hide, () => setState(() => _hide = !_hide), onSubmitted: (_) => _submit()),
      const SizedBox(height: 4),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: _busy ? null : _forgotPassword,
          child: const Text('نسيت كلمة المرور؟'),
        ),
      ),
    ];
  }

  // ── حقول إنشاء الحساب ──
  List<Widget> _signupFields() {
    final c = _country;
    return [
      _field(controller: _name, hint: 'الاسم الكامل', icon: Icons.person_outline_rounded, textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      _field(
        controller: _email,
        hint: 'البريد الإلكتروني',
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: _pickCountry,
            borderRadius: BorderRadius.circular(EFR.control),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(EFR.control),
                border: Border.all(color: AppColors.lineSoft),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('+${c.dial}', style: const TextStyle(color: AppColors.nu, fontWeight: FontWeight.w900)),
                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.muted),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field(
              controller: _phone,
              hint: 'رقم الهاتف (اختياري)',
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _passwordField(_pass, 'كلمة المرور', _hide, () => setState(() => _hide = !_hide), textInputAction: TextInputAction.next),
      if (_pass.text.isNotEmpty && _passwordProblem(_pass.text) != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Semantics(liveRegion: true, child: Text(
            _passwordProblem(_pass.text)!,
            style: const TextStyle(color: AppColors.wo2, fontSize: 13, height: 1.5))),
        ),
      const SizedBox(height: 14),
      _passwordField(_pass2, 'تأكيد كلمة المرور', _hide2, () => setState(() => _hide2 = !_hide2), onSubmitted: (_) => _submit()),
    ];
  }

  Widget _passwordField(TextEditingController controller, String hint, bool hidden, VoidCallback onToggle,
      {TextInputAction? textInputAction, ValueChanged<String>? onSubmitted}) {
    return _field(
      controller: controller,
      hint: hint,
      icon: Icons.lock_outline_rounded,
      obscure: hidden,
      textInputAction: textInputAction ?? TextInputAction.done,
      onSubmitted: onSubmitted,
      suffix: IconButton(
        tooltip: hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.muted),
        onPressed: onToggle,
      ),
    );
  }

  Widget _orDivider() {
    return Row(children: const [
      Expanded(child: Divider(color: AppColors.lineSoft, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('أو', style: TextStyle(color: AppColors.faint, fontWeight: FontWeight.w700)),
      ),
      Expanded(child: Divider(color: AppColors.lineSoft, thickness: 1)),
    ]);
  }

  Widget _googleButton(String label) {
    return Pressable(
      onTap: _busy ? null : _google,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(EFR.control),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _googleMark(),
          const SizedBox(width: 11),
          Text(label, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
        ]),
      ),
    );
  }

  Widget _googleMark() {
    // شعار Google: لو فيه assets/google.png بيتعرض، غير كده حرف G ملون.
    return Image.asset(
      'assets/google.png',
      width: 22,
      height: 22,
      errorBuilder: (_, __, ___) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
  }

  Widget _field({
    Key? key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: formatters,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _cta() {
    return Pressable(
      onTap: _busy ? null : _submit,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EFR.control),
          gradient: const LinearGradient(colors: [AppColors.nu, AppColors.nu2]),
          boxShadow: [BoxShadow(color: AppColors.nu.withValues(alpha: .30), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        alignment: Alignment.center,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onNu))
            : Text(
                _login ? 'تسجيل الدخول' : 'إنشاء حساب',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: AppColors.onNu),
              ),
      ),
    );
  }
}
