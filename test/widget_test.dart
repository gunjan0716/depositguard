import 'package:depositguard/main.dart';
import 'package:depositguard/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding → demo → navigate to move-out', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    await tester.pumpWidget(AppScope(state: state, child: const DepositGuardApp()));

    expect(find.text('Protect your security deposit'), findsOneWidget);

    await tester.tap(find.text('Just exploring? Load demo data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Namaste'), findsOneWidget);
    expect(find.text('₹1,50,000'), findsOneWidget);

    await tester.tap(find.text('Move-out'));
    await tester.pumpAndSettle();
    expect(find.text('Move-out comparison'), findsOneWidget);
    expect(find.text('₹1,12,334'), findsOneWidget);
  });
}
