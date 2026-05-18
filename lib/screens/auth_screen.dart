import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

enum _AuthMode { login, register, forgot }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _rememberMeKey = 'rememberMe';
  static const _preferLoginKey = 'authPreferLoginNextLaunch';
  static const _savedEmailKey = 'authSavedEmail';

  _AuthMode _mode = _AuthMode.register;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _rememberMe = true;
  bool _busy = false;
  String? _error;
  bool _prefsLoaded = false;

  ButtonStyle get _linkButtonStyle => TextButton.styleFrom(
        foregroundColor: const Color(0xFFFFE082),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAuthPrefs());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadAuthPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final preferLogin = prefs.getBool(_preferLoginKey) ?? false;
    final remember = prefs.getBool(_rememberMeKey) ?? true;
    final savedEmail = prefs.getString(_savedEmailKey);
    if (!mounted) return;
    setState(() {
      _prefsLoaded = true;
      _mode = preferLogin ? _AuthMode.login : _AuthMode.register;
      _rememberMe = remember;
      if (remember && savedEmail != null && savedEmail.isNotEmpty) {
        _email.text = savedEmail;
      }
    });
  }

  Future<void> _setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
    if (!mounted) return;
    setState(() => _rememberMe = value);
  }

  Future<void> _persistAfterSuccessfulAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferLoginKey, true);
    if (_rememberMe) {
      await prefs.setString(_savedEmailKey, _email.text.trim());
    } else {
      await prefs.remove(_savedEmailKey);
    }
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _setRememberMe(_rememberMe);
      await _persistAfterSuccessfulAuth();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? context.t('loginFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = context.t('passwordMismatch'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _setRememberMe(_rememberMe);
      await _persistAfterSuccessfulAuth();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? context.t('registerFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('resetMailSent'))),
      );
      setState(() => _mode = _AuthMode.login);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? context.t('processFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final isLogin = _mode == _AuthMode.login;
    final isRegister = _mode == _AuthMode.register;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(text: 'Safe', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Her', style: TextStyle(color: AppTheme.brandPink)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isLogin
                          ? context.t('login')
                          : isRegister
                              ? context.t('register')
                              : context.t('forgotPassword'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: context.t('email'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_mode != _AuthMode.forgot) ...[
                      TextField(
                        controller: _password,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: context.t('password'),
                        ),
                      ),
                      if (isRegister) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confirm,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.t('passwordAgain'),
                          ),
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.pinkAccent),
                      ),
                    ],
                    if (_mode != _AuthMode.forgot) ...[
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        value: _rememberMe,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.brandPink,
                        checkColor: Colors.white,
                        title: Text(
                          context.t('rememberMe'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        onChanged: _busy
                            ? null
                            : (v) => _setRememberMe(v ?? true),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : isLogin
                              ? _login
                              : isRegister
                                  ? _register
                                  : _forgot,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isLogin
                                  ? context.t('login')
                                  : isRegister
                                      ? context.t('register')
                                      : context.t('sendResetLink'),
                            ),
                    ),
                    const SizedBox(height: 8),
                    if (_mode == _AuthMode.login) ...[
                      TextButton(
                        style: _linkButtonStyle,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _mode = _AuthMode.register),
                        child: Text(context.t('noAccountRegister')),
                      ),
                      TextButton(
                        style: _linkButtonStyle,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _mode = _AuthMode.forgot),
                        child: Text(context.t('forgotPasswordShort')),
                      ),
                    ],
                    if (_mode == _AuthMode.register)
                      TextButton(
                        style: _linkButtonStyle,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _mode = _AuthMode.login),
                        child: Text(context.t('haveAccountLogin')),
                      ),
                    if (_mode == _AuthMode.forgot)
                      TextButton(
                        style: _linkButtonStyle,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _mode = _AuthMode.login),
                        child: Text(context.t('backToLogin')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
