import 'package:flutter_test/flutter_test.dart';

import 'package:acadex_mobile/main.dart';

void main() {
  testWidgets('shows setup when Supabase env is missing', (tester) async {
    await tester.pumpWidget(const AcadexApp());
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
