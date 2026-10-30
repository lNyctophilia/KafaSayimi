import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafa_sayimi/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KafaSayimiApp(),
      ),
    );
    expect(find.byType(KafaSayimiApp), findsOneWidget);
  });
}
