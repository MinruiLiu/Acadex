import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cupertino_toast.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    setState(() => _busy = true);
    try {
      if (_signUp) {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
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
            CupertinoTextField(
              controller: _emailController,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
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
                  : () => setState(() => _signUp = !_signUp),
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
