import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cupertino_toast.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

Widget _authFieldLabel(BuildContext context, String text, {required bool requiredField}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.label.resolveFrom(context),
        ),
        children: [
          TextSpan(text: text),
          if (requiredField)
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ),
  );
}

final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showAcadexToast(
        context,
        'Please enter email and password.',
        variant: AcadexToastVariant.neutral,
      );
      return;
    }
    if (_signUp) {
      final username = _usernameController.text.trim();
      if (username.isNotEmpty && !_usernameRe.hasMatch(username)) {
        showAcadexToast(
          context,
          'Username must be 3–32 characters: letters, numbers, and underscores only.',
          variant: AcadexToastVariant.neutral,
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      if (_signUp) {
        final username = _usernameController.text.trim();
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: username.isEmpty ? {} : {'username': username},
        );
        if (!mounted) return;
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          showAcadexToast(
            context,
            'Check your email to confirm, or disable email confirmation in Supabase Auth settings for dev.',
            variant: AcadexToastVariant.neutral,
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        showAcadexToast(context, e.message, variant: AcadexToastVariant.danger);
      }
    } catch (e) {
      if (mounted) {
        showAcadexToast(context, e.toString(), variant: AcadexToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sign in'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            const Text(
              'Use the same email provider you enabled in Supabase (e.g. Email).',
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            _authFieldLabel(context, 'Email', requiredField: true),
            CupertinoTextField(
              controller: _emailController,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
            ),
            if (_signUp) ...[
              const SizedBox(height: 8),
              _authFieldLabel(context, 'Username', requiredField: false),
              CupertinoTextField(
                controller: _usernameController,
                placeholder: 'Optional · 3–32 letters, numbers, _',
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
              ),
            ],
            const SizedBox(height: 8),
            _authFieldLabel(context, 'Password', requiredField: true),
            CupertinoTextField(
              controller: _passwordController,
              placeholder: 'Password',
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : Text(_signUp ? 'Sign up' : 'Sign in'),
            ),
            CupertinoButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _signUp = !_signUp;
                      if (!_signUp) _usernameController.clear();
                    }),
              child: Text(
                _signUp
                    ? 'Have an account? Sign in'
                    : 'Need an account? Sign up',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
