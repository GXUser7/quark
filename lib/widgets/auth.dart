import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart'; // Проверь название пакета в pubspec
import 'package:quark/services/database/settings_engine.dart';
import 'package:quark/widgets/forgot_pass_page.dart';
import 'package:quark/widgets/animated_glow.dart';
import '../services/auth_services.dart';
import '../services/database/database.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _authService = AuthService();

  int _tabIndex = 0;
  bool _loginPassVisible = false;
  bool _regPassVisible = false;
  bool _regConfirmVisible = false;
  bool _isLoading = false;

  // Состояние верификации почты
  bool _isVerifyingEmail = false;
  String _registeredEmail = '';

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _regUsernameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  String? _validateLogin() {
    if (_loginEmailCtrl.text.trim().isEmpty) return 'Введите email';
    if (!_loginEmailCtrl.text.contains('@')) return 'Некорректный email';
    if (_loginPasswordCtrl.text.isEmpty) return 'Введите пароль';
    return null;
  }

  String? _validateRegister() {
    if (_regUsernameCtrl.text.trim().length < 2) return 'Имя минимум 2 символа';
    if (!_regEmailCtrl.text.contains('@')) return 'Некорректный email';
    if (_regPasswordCtrl.text.length < 8) return 'Пароль минимум 8 символов';
    if (_regPasswordCtrl.text != _regConfirmCtrl.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    final error = _validateLogin();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.login(
        _loginEmailCtrl.text.trim(),
        _loginPasswordCtrl.text,
      );
      _onSuccess();
    } catch (e) {
      _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final error = _validateRegister();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _regEmailCtrl.text.trim();
      await _authService.register(
        email,
        _regPasswordCtrl.text,
        _regUsernameCtrl.text.trim(),
      );
      
      // Переключаем форму на ввод OTP кода подтверждения
      setState(() {
        _registeredEmail = email;
        _isVerifyingEmail = true;
      });
    } catch (e) {
      _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyEmail(String code) async {
    setState(() => _isLoading = true);
    try {
      await _authService.verifyEmail(code: code, email: _registeredEmail);
      _onSuccess();
    } catch (e) {
      _showError('Неверный код или срок его действия истек');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendCode() async {
    try {
      await _authService.resendVerificationCode(_registeredEmail);
      _showNotification('Код отправлен повторно');
    } catch (e) {
      _showError('Не удалось отправить код повторно');
    }
  }

  void _onSuccess() async {
    if (!mounted) return;
    await Database.put('isLoggedIn', true);
    Navigator.pop(context);
  }

  void _showNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14)),
        backgroundColor: const Color(0xFF32D74B).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
  }

  void _showError(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.error.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid email or password')) return 'Неверный email или пароль';
    if (msg.contains('Email already registered')) return 'Email уже зарегистрирован';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Нет подключения к серверу';
    }
    return 'Что-то пошло не так';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedGlowBackground(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.15),
                          theme.colorScheme.primary.withOpacity(0.03),
                        ],
                      ),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isVerifyingEmail ? Icons.mark_email_read_rounded : Icons.lock_rounded,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (!_isVerifyingEmail) ...[
                  _TabSwitcher(
                    selectedIndex: _tabIndex,
                    labels: const ['Вход', 'Регистрация'],
                    onChanged: (i) {
                      setState(() => _tabIndex = i);
                      ScaffoldMessenger.of(context).clearSnackBars();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: anim.drive(
                              Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                                  .chain(CurveTween(curve: Curves.easeOutCubic)),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _isVerifyingEmail
                          ? _EmailVerificationStep(
                              key: const ValueKey('verification'),
                              email: _registeredEmail,
                              isLoading: _isLoading,
                              onVerify: _handleVerifyEmail,
                              onResend: _handleResendCode,
                            )
                          : _tabIndex == 0
                              ? _LoginForm(
                                  key: const ValueKey('login'),
                                  emailCtrl: _loginEmailCtrl,
                                  passwordCtrl: _loginPasswordCtrl,
                                  passwordVisible: _loginPassVisible,
                                  onTogglePassword: () => setState(() => _loginPassVisible = !_loginPassVisible),
                                  isLoading: _isLoading,
                                  onSubmit: _handleLogin,
                                )
                              : _RegisterForm(
                                  key: const ValueKey('register'),
                                  usernameCtrl: _regUsernameCtrl,
                                  emailCtrl: _regEmailCtrl,
                                  passwordCtrl: _regPasswordCtrl,
                                  confirmCtrl: _regConfirmCtrl,
                                  passwordVisible: _regPassVisible,
                                  confirmVisible: _regConfirmVisible,
                                  onTogglePassword: () => setState(() => _regPassVisible = !_regPassVisible),
                                  onToggleConfirm: () => setState(() => _regConfirmVisible = !_regConfirmVisible),
                                  isLoading: _isLoading,
                                  onSubmit: _handleRegister,
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Вспомогательный виджет верификации почты ──
class _EmailVerificationStep extends StatefulWidget {
  final String email;
  final bool isLoading;
  final Function(String code) onVerify;
  final VoidCallback onResend;

  const _EmailVerificationStep({
    super.key,
    required this.email,
    required this.isLoading,
    required this.onVerify,
    required this.onResend,
  });

  @override
  State<_EmailVerificationStep> createState() => _EmailVerificationStepState();
}

class _EmailVerificationStepState extends State<_EmailVerificationStep> {
  final _pinCtrl = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Подтвердите почту',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Мы отправили код верификации на:\n${widget.email}',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white.withOpacity(0.55), height: 1.4),
          ),
          const SizedBox(height: 28),
          Center(
            child: MaterialPinField(
              mainAxisAlignment: MainAxisAlignment.center,
              length: 6,
              keyboardType: TextInputType.number,
              autoFocus: true,
              theme: MaterialPinTheme(
                shape: MaterialPinShape.outlined,
                borderRadius: BorderRadius.circular(12),
                borderWidth: 1.5,
              ),
              onChanged: (_) {
                if (_hasError) setState(() => _hasError = false);
              },
              onCompleted: (value) => widget.onVerify(value), // Прямая безопасная передача значения
            ),
          ),
          AnimatedOpacity(
            opacity: _hasError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Неверный или устаревший код',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: theme.colorScheme.error, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            text: 'Подтвердить почту',
            isLoading: widget.isLoading,
            onTap: () {
              if (_pinCtrl.text.length < 6) {
                setState(() => _hasError = true);
              } else {
                widget.onVerify(_pinCtrl.text);
              }
            },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onResend,
            style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.5)),
            child: Text(
              'Отправить код повторно',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _TabSwitcher({required this.selectedIndex, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? Colors.white.withOpacity(0.04) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel ? Border.all(color: Colors.white.withOpacity(0.06)) : Border.all(color: Colors.transparent),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? Colors.white : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final TextEditingController emailCtrl, passwordCtrl;
  final bool passwordVisible, isLoading;
  final VoidCallback onTogglePassword, onSubmit;

  const _LoginForm({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.passwordVisible,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomField(
            controller: emailCtrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _CustomField(
            controller: passwordCtrl,
            label: 'Пароль',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon: _EyeButton(visible: passwordVisible, onTap: onTogglePassword),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(text: 'Войти', isLoading: isLoading, onTap: onSubmit),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ForgotPasswordPage())),
            style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.5)),
            child: Text(
              'Забыл пароль?',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  final bool passwordVisible, confirmVisible, isLoading;
  final TextEditingController usernameCtrl, emailCtrl, passwordCtrl, confirmCtrl;
  final VoidCallback onTogglePassword, onToggleConfirm, onSubmit;

  const _RegisterForm({
    super.key,
    required this.usernameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomField(
            controller: usernameCtrl,
            label: 'Имя пользователя',
            hint: 'username',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _CustomField(
            controller: emailCtrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _CustomField(
            controller: passwordCtrl,
            label: 'Пароль',
            hint: 'Минимум 8 символов',
            icon: Icons.lock_outline_rounded,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.next,
            suffixIcon: _EyeButton(visible: passwordVisible, onTap: onTogglePassword),
          ),
          const SizedBox(height: 16),
          _CustomField(
            controller: confirmCtrl,
            label: 'Подтвердите пароль',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: !confirmVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon: _EyeButton(visible: confirmVisible, onTap: onToggleConfirm),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(text: 'Создать аккаунт', isLoading: isLoading, onTap: onSubmit),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLightAccent = theme.colorScheme.primary.computeLuminance() > 0.5;

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: isLightAccent ? Colors.black : Colors.white,
          disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: isLightAccent ? Colors.black : Colors.white),
              )
            : Text(
                text,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;
  const _EyeButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: Colors.white.withOpacity(0.4),
        ),
        onPressed: onTap,
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.white.withOpacity(0.01)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _CustomField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _CustomField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.5)),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.25), fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: Colors.white.withOpacity(0.4)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}