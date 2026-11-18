import 'package:flutter_test/flutter_test.dart';

import 'package:mint_rate_tracker/main.dart';

void main() {
  testWidgets('renders the MINT overview', (tester) async {
    await tester.pumpWidget(const MintApp());

    expect(find.text('MINT'), findsOneWidget);
    expect(find.textContaining('Gold 24K'), findsOneWidget);
  });

  testWidgets('opens the new alert sheet', (tester) async {
    await tester.pumpWidget(const MintApp());
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Create alert'), findsOneWidget);
    expect(find.text('Save alert'), findsOneWidget);
  });
}
