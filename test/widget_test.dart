import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_rate_tracker/main.dart';

/// The mock's phone: 390 x 844 logical pixels.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the MINT overview', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(const MintApp());

    expect(find.text('Mint'), findsOneWidget);
    expect(find.text('GOLD 24K · PER TOLA'), findsOneWidget);
  });

  testWidgets('opens the new alert sheet', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(const MintApp());
    await tester.tap(find.byTooltip('Set an alert'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Set an alert'), findsOneWidget);
    expect(find.text('Keep this alert'), findsOneWidget);
  });

  testWidgets('an empty target is refused plainly, not silently', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(const MintApp());
    await tester.tap(find.byTooltip('Set an alert'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Keep this alert'));
    await tester.pump();
    await tester.tap(find.text('Keep this alert'));
    await tester.pump();

    expect(find.textContaining('Enter a figure above zero'), findsOneWidget);
    expect(find.text('Keep this alert'), findsOneWidget);
  });

  testWidgets('a kept alert answers in one word and appears on Alerts', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(const MintApp());
    await tester.tap(find.byTooltip('Set an alert'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(EditableText).last, '400000');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Keep this alert'));
    await tester.pump();
    await tester.tap(find.text('Keep this alert'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Kept.'), findsOneWidget);
    expect(
      find.text('Rings once when Gold 24K above Rs 400,000.'),
      findsOneWidget,
    );
    await tester.tap(find.text('ALERTS'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gold 24K above Rs 400,000'), findsOneWidget);
  });
}
