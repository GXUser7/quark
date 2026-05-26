import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quark/services/forgot_pass_page.dart';
import 'dart:math';
import '../services/auth_services.dart';
import '../services/database/database.dart';
import '../services//database/settings_engine.dart';
import 'players_widgets/gnome_like_widgets.dart';

const _adwColor = Color.fromARGB(186, 109, 109, 109);
const _bgPage = Color(0xFF1C1C1E);
const _bgCard = Color(0xFF2A2A2E);
const _bgField = Color(0xFF1C1C1E);
const _bgTabBar = Color(0xFF242428);
const _borderColor = Color(0xFF3A3A40);
const _mutedColor = Color(0xFF8E8E93);
const _textPrimary = Color(0xFFEFEFF0);
const _errorColor = Color(0xFFFF453A);
const _successColor = Color(0xFF32D74B);

ThemeData _buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _adwColor,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: _bgPage,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      themeMode: ThemeMode.dark,
      home: const AuthPage(),
    );
  }
}

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

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _regUsernameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

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
    if (_regPasswordCtrl.text != _regConfirmCtrl.text)
      return 'Пароли не совпадают';
    return null;
  }

  // HANDLING
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
      await _authService.register(
        _regEmailCtrl.text.trim(),
        _regPasswordCtrl.text,
        _regUsernameCtrl.text.trim(),
      );
      _onSuccess();
    } catch (e) {
      _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSuccess() async {
    if (!mounted) return;
    await Database.put('isLoggedIn', true);
    Navigator.pop(context);
    // TODO: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
  }

  void _showError(String message) {
    if (!mounted) return;
    _showSnack(message, _errorColor);
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _errorColor
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid email or password'))
      return 'Неверный email или пароль';
    if (msg.contains('Email already registered'))
      return 'Email уже зарегистрирован';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Нет подключения к серверу';
    }
    return 'Что-то пошло не так';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Иконка
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _adwColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _adwColor.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _TabSwitcher(
                  selectedIndex: _tabIndex,
                  labels: const ['Вход', 'Регистрация'],
                  onChanged: (i) {
                    setState(() => _tabIndex = i);
                    ScaffoldMessenger.of(context).clearSnackBars();
                  },
                ),
                const SizedBox(height: 20),

                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: _tabIndex == 0
                          ? _LoginForm(
                              key: const ValueKey('login'),
                              emailCtrl: _loginEmailCtrl,
                              passwordCtrl: _loginPasswordCtrl,
                              passwordVisible: _loginPassVisible,
                              onTogglePassword: () => setState(
                                () => _loginPassVisible = !_loginPassVisible,
                              ),
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
                              onTogglePassword: () => setState(
                                () => _regPassVisible = !_regPassVisible,
                              ),
                              onToggleConfirm: () => setState(
                                () => _regConfirmVisible = !_regConfirmVisible,
                              ),
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

class _TabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _TabSwitcher({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgTabBar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _bgCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: sel ? Border.all(color: _borderColor) : null,
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? _textPrimary : _mutedColor,
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
          _AdwField(
            controller: emailCtrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _AdwField(
            controller: passwordCtrl,
            label: 'Пароль',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon: _EyeButton(
              visible: passwordVisible,
              onTap: onTogglePassword,
            ),
          ),
          const SizedBox(height: 20),
          GnomeButton(text: 'Войти', isLoading: isLoading, onTap: onSubmit),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ForgotPasswordPage()),
              ),
              child: const Text('Забыл пароль?',
                  style: TextStyle(color: _mutedColor, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  final bool passwordVisible, confirmVisible, isLoading;
  final TextEditingController usernameCtrl,
      emailCtrl,
      passwordCtrl,
      confirmCtrl;
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
          _AdwField(
            controller: usernameCtrl,
            label: 'Имя пользователя',
            hint: 'username',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _AdwField(
            controller: emailCtrl,
            label: 'Электронная почта',
            hint: 'user@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _AdwField(
            controller: passwordCtrl,
            label: 'Пароль',
            hint: 'Минимум 8 символов',
            icon: Icons.lock_outline_rounded,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.next,
            suffixIcon: _EyeButton(
              visible: passwordVisible,
              onTap: onTogglePassword,
            ),
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
            suffixIcon: _EyeButton(
              visible: confirmVisible,
              onTap: onToggleConfirm,
            ),
          ),
          const SizedBox(height: 20),
          GnomeButton(
            text: 'Создать аккаунт',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
        ],
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
      size: 18,
      color: _mutedColor,
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _mutedColor,
          ),
        ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: _adwColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
