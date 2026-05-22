import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tam uygulama testi Firebase vb. kurulum gerektirir; CI/analiz için hafif duman testi.
void main() {
  testWidgets('Widget test harness smoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('SafeHer'),
        ),
      ),
    );
    expect(find.text('SafeHer'), findsOneWidget);
  });
}
