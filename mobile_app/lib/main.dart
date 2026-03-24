import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const AcadexApp());
}

class AcadexApp extends StatelessWidget {
  const AcadexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Acadex',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: Env.isConfigured ? const AuthGate() : const _ConfigMissingPage(),
    );
  }
}

class _ConfigMissingPage extends StatelessWidget {
  const _ConfigMissingPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Setup'),
        border: null,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Run the app with:\n\n'
            '--dart-define=SUPABASE_URL=your_url '
            '--dart-define=SUPABASE_ANON_KEY=your_anon_key\n\n'
            'See lib/env.dart.',
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
        ),
      ),
    );
  }
}
