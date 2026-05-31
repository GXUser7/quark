import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_services.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = AuthService();

  int _step = 0;
  bool _isLoading = false;

  String _email = '';
  String _code = '';
  bool _newPassVisible = false;
  bool _confirmPassVisible = false;

  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _pinHasError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String get _enteredCode => _pinCtrl.text;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('Введите корректный email', true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.forgotPassword(email);
      setState(() {
        _email = email;
        _step = 1;
      });
    } catch (e) {
      _snack('Ошибка соединения с сервером', true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode([String? explicitCode]) async {
    final code = explicitCode ?? _enteredCode;

    if (code.length < 6) {
      setState(() => _pinHasError = true);
      _snack('Введите все 6 цифр', true);
      return;
    }
    setState(() {
      _code = code;
      _step = 2;
    });
  }

  Future<void> _setNewPassword() async {
    final np = _newPassCtrl.text;
    final cp = _confirmCtrl.text;
    if (np.length < 8) {
      _snack('Пароль минимум 8 символов', true);
      return;
    }
    if (np != cp) {
      _snack('Пароли не совпадают', true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.resetPassword(email: _email, code: _code, newPassword: np);
      _snack('Пароль успешно изменён', false);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Invalid or expired code')) {
        _snack('Код устарел — вернитесь и запросите новый', true);
        _pinCtrl.clear();
        setState(() {
          _step = 0;
          _pinHasError = false;
        });
      } else {
        _snack('Что-то пошло не так', true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String text, bool isError) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final targetColor = isError
        ? theme.colorScheme.error
        : const Color(0xFF32D74B);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: targetColor.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.08),
                    theme.colorScheme.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Centered step indicator ──
                    Center(child: _StepIndicator(current: _step, total: 3)),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: anim.drive(
                              Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeOutCubic)),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _step == 0
                          ? _EmailStep(
                              key: const ValueKey(0),
                              ctrl: _emailCtrl,
                              isLoading: _isLoading,
                              onSubmit: _sendCode,
                            )
                          : _step == 1
                          ? _CodeStep(
                              key: const ValueKey(1),
                              email: _email,
                              pinCtrl: _pinCtrl,
                              hasError: _pinHasError,
                              onChanged: (_) {
                                if (_pinHasError)
                                  setState(() => _pinHasError = false);
                              },
                              onCompleted: (value) => _verifyCode(value),
                              isLoading: _isLoading,
                              onSubmit: () =>
                                  _verifyCode(), 
                              onResend: () {
                                _pinCtrl.clear();
                                setState(() {
                                  _step = 0;
                                  _pinHasError = false;
                                });
                              },
                            )
                          : _NewPasswordStep(
                              key: const ValueKey(2),
                              newPassCtrl: _newPassCtrl,
                              confirmCtrl: _confirmCtrl,
                              newPassVisible: _newPassVisible,
                              confirmVisible: _confirmPassVisible,
                              onToggleNew: () => setState(
                                () => _newPassVisible = !_newPassVisible,
                              ),
                              onToggleConfirm: () => setState(
                                () =>
                                    _confirmPassVisible = !_confirmPassVisible,
                              ),
                              isLoading: _isLoading,
                              onSubmit: _setNewPassword,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _EmailStep({
    super.key,
    required this.ctrl,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Введите email',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Отправим 6-значный код для сброса пароля.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 24),
          _CustomField(
            controller: ctrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            text: 'Отправить код',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  final String email;
  final TextEditingController pinCtrl;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _CodeStep({
    super.key,
    required this.email,
    required this.pinCtrl,
    required this.hasError,
    required this.onChanged,
    required this.onCompleted,
    required this.isLoading,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Введите код',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Код отправлен на $email',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 28),
          // ── Centered PIN field ──
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
              onChanged: onChanged,
              onCompleted: onCompleted,
            ),
          ),
          AnimatedOpacity(
            opacity: hasError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Неверный или устаревший код',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            text: 'Подтвердить',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onResend,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.5),
            ),
            child: Text(
              'Отправить код повторно',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPasswordStep extends StatelessWidget {
  final TextEditingController newPassCtrl, confirmCtrl;
  final bool newPassVisible, confirmVisible, isLoading;
  final VoidCallback onToggleNew, onToggleConfirm, onSubmit;

  const _NewPasswordStep({
    super.key,
    required this.newPassCtrl,
    required this.confirmCtrl,
    required this.newPassVisible,
    required this.confirmVisible,
    required this.isLoading,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Новый пароль',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Придумайте пароль минимум из 8 символов.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 24),
          _CustomField(
            controller: newPassCtrl,
            label: 'Новый пароль',
            hint: 'Минимум 8 символов',
            icon: Icons.lock_outline_rounded,
            obscureText: !newPassVisible,
            textInputAction: TextInputAction.next,
            suffixIcon: _EyeButton(visible: newPassVisible, onTap: onToggleNew),
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
            suffixIcon: _EyeButton(
              visible: confirmVisible,
              onTap: onToggleConfirm,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            text: 'Сохранить пароль',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────
// Uses mainAxisSize.min so the row shrinks to content width and stays centered
// when wrapped in Center() at the call site.
class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['Email', 'Код', 'Пароль'];

    return Row(
      mainAxisSize: MainAxisSize.min, // shrink-wrap → Center does the rest
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(total * 2 - 1, (index) {
        // Odd slots → connector lines between steps
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final done = stepIndex < current;
          return Padding(
            padding: const EdgeInsets.only(
              top: 15,
              bottom: 0,
            ), // vertically align with circle centres
            child: Container(
              width: 36,
              height: 2,
              color: done
                  ? const Color(0xFF32D74B)
                  : Colors.white.withOpacity(0.08),
            ),
          );
        }

        // Even slots → step circles + labels
        final i = index ~/ 2;
        final done = i < current;
        final active = i == current;

        final circleColor = done
            ? const Color(0xFF32D74B)
            : active
            ? theme.colorScheme.primary
            : Colors.white.withOpacity(0.04);

        final borderColor = done
            ? const Color(0xFF32D74B)
            : active
            ? theme.colorScheme.primary
            : Colors.white.withOpacity(0.08);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  if (active || done)
                    BoxShadow(
                      color: circleColor.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '${i + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              labels[i],
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onTap,
  });

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isLightAccent ? Colors.black : Colors.white,
                ),
              )
            : Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
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
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.white.withOpacity(0.01),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
            ),
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
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.25),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: Colors.white.withOpacity(0.4),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
