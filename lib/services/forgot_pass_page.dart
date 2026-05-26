import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

// ─── Цветовая схема (те же константы, что в auth_page.dart) ─────────────────
const _adwColor    = Color.fromARGB(186, 109, 109, 109);
const _bgPage      = Color(0xFF1C1C1E);
const _bgCard      = Color(0xFF2A2A2E);
const _bgField     = Color(0xFF1C1C1E);
const _bgTabBar    = Color(0xFF242428);
const _borderColor = Color(0xFF3A3A40);
const _mutedColor  = Color(0xFF8E8E93);
const _textPrimary = Color(0xFFEFEFF0);
const _errorColor  = Color(0xFFFF453A);
const _successColor = Color(0xFF32D74B);
const _accentColor = Color(0xFF0A84FF);

// ─── Точка входа: кнопка «Забыл пароль» на экране логина ────────────────────
//
// Добавить в _LoginForm:
//
//   TextButton(
//     onPressed: () => Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
//     ),
//     child: const Text('Забыл пароль?',
//         style: TextStyle(color: _mutedColor, fontSize: 13)),
//   ),

/// Трёхшаговый экран восстановления пароля:
///   Шаг 1 — ввод email
///   Шаг 2 — ввод кода из письма
///   Шаг 3 — новый пароль
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = AuthService();

  // Шаги: 0 = email, 1 = code, 2 = new password
  int _step = 0;
  bool _isLoading = false;

  String _email     = '';
  String _code      = '';
  bool _newPassVisible    = false;
  bool _confirmPassVisible = false;

  final _emailCtrl   = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  // PinCodeTextField управляет вводом сам — нам нужен только текстовый контроллер
  // и стрим для сигнализации об ошибках
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

  // ── Шаг 1: отправить код ─────────────────────────────────────────────────
  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('Введите корректный email', _errorColor);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.forgotPassword(email);
      setState(() { _email = email; _step = 1; });
    } catch (e) {
      _snack('Ошибка соединения с сервером', _errorColor);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Шаг 2: подтвердить код ───────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _pinHasError = true);
      _snack('Введите все 6 цифр', _errorColor);
      return;
    }
    setState(() { _code = code; _step = 2; });
  }

  // ── Шаг 3: установить новый пароль ───────────────────────────────────────
  Future<void> _setNewPassword() async {
    final np = _newPassCtrl.text;
    final cp = _confirmCtrl.text;
    if (np.length < 8) {
      _snack('Пароль минимум 8 символов', _errorColor);
      return;
    }
    if (np != cp) {
      _snack('Пароли не совпадают', _errorColor);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.resetPassword(email: _email, code: _code, newPassword: np);
      _snack('Пароль успешно изменён', _successColor);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Invalid or expired code')) {
        _snack('Код устарел — вернитесь и запросите новый', _errorColor);
        setState(() => _step = 0);
      } else {
        _snack('Что-то пошло не так', _errorColor);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            color == _errorColor ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _bgPage,
        foregroundColor: _textPrimary,
        title: const Text('Восстановление пароля',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор шагов
                _StepIndicator(current: _step, total: 3),
                const SizedBox(height: 28),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
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
                                if (_pinHasError) setState(() => _pinHasError = false);
                              },
                              onCompleted: (_) => _verifyCode(),
                              isLoading: _isLoading,
                              onSubmit: _verifyCode,
                              onResend: () {
                                _pinCtrl.clear();
                                setState(() { _step = 0; _pinHasError = false; });
                              },
                            )
                          : _NewPasswordStep(
                              key: const ValueKey(2),
                              newPassCtrl: _newPassCtrl,
                              confirmCtrl: _confirmCtrl,
                              newPassVisible: _newPassVisible,
                              confirmVisible: _confirmPassVisible,
                              onToggleNew: () => setState(
                                  () => _newPassVisible = !_newPassVisible),
                              onToggleConfirm: () => setState(
                                  () => _confirmPassVisible = !_confirmPassVisible),
                              isLoading: _isLoading,
                              onSubmit: _setNewPassword,
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

// ── Шаг 1: Email ─────────────────────────────────────────────────────────────
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
          const Text('Введите email',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Отправим 6-значный код для сброса пароля.',
            style: TextStyle(fontSize: 13, color: _mutedColor),
          ),
          const SizedBox(height: 20),
          _AdwField(
            controller: ctrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
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

// ── Шаг 2: Код из письма ─────────────────────────────────────────────────────
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Введите код',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Код отправлен на $email',
            style: const TextStyle(fontSize: 13, color: _mutedColor),
          ),
          const SizedBox(height: 28),

          MaterialPinField(
            length: 6,
            obscureText: false,
            keyboardType: TextInputType.number,
            autoFocus: true,
            theme: MaterialPinTheme(
              shape: MaterialPinShape.outlined,
              borderRadius: BorderRadius.circular(10),
              // Толщина рамки
              borderWidth: 1.8,
            ),
            hintStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
            onChanged: onChanged,
            onCompleted: onCompleted,
          ),

          // Подсказка об ошибке под полем
          AnimatedOpacity(
            opacity: hasError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Неверный или устаревший код',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _errorColor),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _PrimaryButton(
            text: 'Подтвердить',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onResend,
            child: const Text(
              'Отправить код повторно',
              style: TextStyle(color: _mutedColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Шаг 3: Новый пароль ───────────────────────────────────────────────────────
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
          const Text('Новый пароль',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Придумайте пароль минимум из 8 символов.',
            style: TextStyle(fontSize: 13, color: _mutedColor),
          ),
          const SizedBox(height: 20),
          _AdwField(
            controller: newPassCtrl,
            label: 'Новый пароль',
            hint: 'Минимум 8 символов',
            icon: Icons.lock_outline_rounded,
            obscureText: !newPassVisible,
            textInputAction: TextInputAction.next,
            suffixIcon: _EyeButton(visible: newPassVisible, onTap: onToggleNew),
          ),
          const SizedBox(height: 12),
          _AdwField(
            controller: confirmCtrl,
            label: 'Подтвердите пароль',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: !confirmVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon:
                _EyeButton(visible: confirmVisible, onTap: onToggleConfirm),
          ),
          const SizedBox(height: 20),
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


class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final labels = ['Email', 'Код', 'Пароль'];
    return Row(
      children: List.generate(total, (i) {
        final done   = i < current;
        final active = i == current;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? _successColor
                          : active
                              ? _accentColor
                              : _bgCard,
                      border: Border.all(
                        color: done
                            ? _successColor
                            : active
                                ? _accentColor
                                : _borderColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : _mutedColor,
                              )),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? _textPrimary : _mutedColor,
                      )),
                ],
              ),
              if (i < total - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: done ? _successColor : _borderColor,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.text, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accentColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
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
          size: 18, color: _mutedColor,
        ),
        onPressed: onTap,
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: child,
      );
}

class _AdwField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _AdwField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _mutedColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14, color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _mutedColor, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: _mutedColor),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _bgField,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accentColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}