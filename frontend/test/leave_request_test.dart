import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_STUDENT/permision_student_role.dart';
import 'package:tamdansers/services/api_models.dart';

// BUGS B38: leave requests stayed on the phone; nobody at school ever saw them.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<LeaveRequestDto> server;
  late List<String> sent;

  Widget screen({String? submitError}) => MaterialApp(
        home: StudentPermissionScreen(
          load: () async => List.of(server),
          submit: (type, date, reason) async {
            sent.add('$type|${date.year}|$reason');
            if (submitError != null) return submitError;
            server.insert(
              0,
              LeaveRequestDto(id: 'n', type: 'Personal', startDate: '2026-10-20', endDate: '2026-10-20', reason: reason, status: 'Pending'),
            );
            return null;
          },
        ),
      );

  Future<void> fillAndSend(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Leave').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Family wedding out of town');
    await tester.ensureVisible(find.byKey(const ValueKey('submit-leave')));
    await tester.tap(find.byKey(const ValueKey('submit-leave')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    sent = [];
    server = [
      LeaveRequestDto(
        id: 'a',
        type: 'Sick',
        startDate: '2026-10-01',
        endDate: '2026-10-02',
        reason: 'Fever',
        status: 'Approved',
        reviewNote: 'Get well soon',
      ),
    ];
  });

  testWidgets('history comes from the school, not sample data', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('APPROVED', skipOffstage: false), findsOneWidget);
    expect(find.text('High fever and flu. Doctor prescribed 3 days of rest.', skipOffstage: false), findsNothing);
  });

  testWidgets('a request is sent to the school and shows as pending', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await fillAndSend(tester);

    expect(sent, ['2|${DateTime.now().year}|Family wedding out of town']);
    expect(find.text('PENDING', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a refused request shows the reason and is not listed', (tester) async {
    await tester.pumpWidget(screen(submitError: 'Your student profile could not be found.'));
    await tester.pumpAndSettle();

    await fillAndSend(tester);

    expect(find.text('Your student profile could not be found.'), findsOneWidget);
    expect(find.text('PENDING', skipOffstage: false), findsNothing);
  });
}
