import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pc_app_bar.dart';
import '../../shared/format.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(text: '+998');
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPhone = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          normalizePhone(_phone.text),
          _password.text,
        );
    if (ok && mounted) context.go('/app');
  }

  Future<void> _telegram() async {
    final ok = await ref.read(authProvider.notifier).loginWithTelegram();
    if (ok && mounted) context.go('/app');
  }

  Future<void> _google() async {
    final ok = await ref.read(authProvider.notifier).loginWithGoogle();
    if (ok && mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2418), AppColors.bg, Color(0xFF08140E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(child: Image.asset('assets/logo.jpg', height: 72)),
                  const SizedBox(height: 16),
                  const Text(
                    'Playzon',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Futbol birlashtiradi. Biz bog‘laymiz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  if (auth.telegramWaiting) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Telegram’da Start bosing',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Bot ochildi. /start bosilgach ilovaga avtomatik kirasiz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(authProvider.notifier).cancelTelegramWait(),
                            child: const Text('Bekor qilish'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    _SocialButton(
                      color: const Color(0xFF2AABEE),
                      icon: Icons.send_rounded,
                      label: 'Telegram orqali kirish',
                      onPressed: auth.busy ? null : _telegram,
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      color: Colors.white,
                      foreground: const Color(0xFF1F1F1F),
                      icon: Icons.g_mobiledata_rounded,
                      label: 'Google orqali kirish',
                      onPressed: auth.busy ? null : _google,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.edge)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'yoki',
                            style: TextStyle(
                              color: AppColors.muted.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.edge)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _showPhone = !_showPhone),
                      child: Text(
                        _showPhone
                            ? 'Telefon formasini yashirish'
                            : 'Telefon + parol bilan',
                      ),
                    ),
                  ],
                  if (_showPhone && !auth.telegramWaiting) ...[
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                      validator: (v) => (v == null || v.trim().length < 9)
                          ? 'Telefon kiriting'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Parol'),
                      validator: (v) =>
                          (v == null || v.length < 4) ? 'Parol kamida 4 belgi' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kirish'),
                    ),
                  ],
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Ro‘yxatdan o‘tish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foreground = Colors.white,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+998');
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          _name.text.trim(),
          normalizePhone(_phone.text),
          _password.text,
        );
    if (ok && mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: pcAppBar(
        context,
        title: 'Ro‘yxatdan o‘tish',),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Ism familiya'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ism kiriting' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  validator: (v) =>
                      (v == null || v.trim().length < 9) ? 'Telefon kiriting' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Parol'),
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Parol kamida 4 belgi' : null,
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Yaratish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _pages = [
    (
      'PLAYZON',
      'Maydon. Jamoa. Turnir.',
      'Stadion bron qiling, ochiq o‘yinga qo‘shiling va jamoangiz bilan o‘ynang.',
      Icons.stadium_outlined,
    ),
    (
      'TICKET',
      'Gold ticket + QR',
      'Bron qilgach ticket olasiz. Stadion egasi QR ni skanerlab kirishni tasdiqlaydi.',
      Icons.qr_code_2,
    ),
    (
      'PRO',
      'FIFA karta va Premium',
      'Profil kartangiz, reels, turnir va To‘p — hammasi bitta ilovada.',
      Icons.workspace_premium,
    ),
  ];

  Future<void> _finish() async {
    await ref.read(tokenStorageProvider).setOnboardingDone();
    ref.invalidate(onboardingDoneProvider);
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2418), AppColors.bg, Color(0xFF08140E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('O‘tkazib yuborish'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Spacer(),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.35),
                                  AppColors.surface2,
                                ],
                              ),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.55)),
                            ),
                            child: Icon(p.$4, size: 44, color: AppColors.gold),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            p.$1,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            p.$3,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.gold
                            : AppColors.edge,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: ElevatedButton(
                  onPressed: () {
                    if (_index < _pages.length - 1) {
                      _page.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1000),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _index < _pages.length - 1 ? 'Davom' : 'Boshlash',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
