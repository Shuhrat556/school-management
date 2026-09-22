import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamdansers/Login/loading.dart';
import 'package:tamdansers/main.dart';

void main() {
  testWidgets('App starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Unmount before the splash's delayed auth check fires, then let the
    // pending timer run out so the test ends without outstanding timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
