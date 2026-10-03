import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/setting/linked_accounts_screen.dart';
import 'package:tamdansers/services/api_models.dart';

// F6: link and unlink Google/Facebook from Settings → Security & Login.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<String> linked;
  late List<String> calls;

  Widget screen({String? linkError}) => MaterialApp(
        home: LinkedAccountsScreen(
          fetch: () async => ExternalLoginsDto(hasPassword: true, providers: List.of(linked)),
          obtainToken: (provider) async => '$provider-token',
          link: (provider, token) async {
            calls.add('link $provider $token');
            if (linkError != null) return linkError;
            linked.add(provider == 'google' ? 'Google' : 'Facebook');
            return null;
          },
          unlink: (provider) async {
            calls.add('unlink $provider');
            linked.removeWhere((p) => p.toLowerCase() == provider);
            return null;
          },
        ),
      );

  setUp(() {
    linked = ['Google'];
    calls = [];
  });

  testWidgets('shows which providers are linked', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('Not linked'), findsOneWidget);
  });

  testWidgets('links a provider with its sign-in token', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('link-facebook')));
    await tester.pumpAndSettle();

    expect(calls, ['link facebook facebook-token']);
    expect(find.text('Linked'), findsNWidgets(2));
  });

  testWidgets('unlinks a provider', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlink-google')));
    await tester.pumpAndSettle();

    expect(calls, ['unlink google']);
    expect(find.text('Not linked'), findsNWidgets(2));
  });

  testWidgets('shows the server reason when linking fails', (tester) async {
    await tester.pumpWidget(screen(linkError: 'This Facebook account is already linked to another user.'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('link-facebook')));
    await tester.pumpAndSettle();

    expect(find.text('This Facebook account is already linked to another user.'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
  });
}
