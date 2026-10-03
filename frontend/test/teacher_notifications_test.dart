import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/notifications_role.dart';
import 'package:tamdansers/services/api_models.dart';

// The teacher's notifications showed sample items ("Sok Pong", "Urgent Meeting"); they now
// list pending leave requests that can be decided on the spot.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<String> decisions;

  Widget screen({String? decideError}) => MaterialApp(
        home: TeacherNotificationScreen(
          loadRequests: () async => [
            LeaveRequestDto(
              id: 'r1',
              type: 'Sick',
              startDate: '2026-10-12',
              endDate: '2026-10-12',
              reason: 'Fever',
              status: 'Pending',
              studentName: 'Nodira Aliyeva',
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
          decide: (id, approve) async {
            decisions.add('$id|$approve');
            return decideError;
          },
        ),
      );

  setUp(() => decisions = []);

  testWidgets('lists pending leave requests instead of sample items', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nodira Aliyeva asked to be excused'), findsOneWidget);
    expect(find.text('Urgent Meeting'), findsNothing);
  });

  testWidgets('approving removes the request from the list', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Nodira Aliyeva asked to be excused'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approve-leave')));
    await tester.pumpAndSettle();

    expect(decisions, ['r1|true']);
    expect(find.textContaining('Nodira Aliyeva asked to be excused'), findsNothing);
    expect(find.text('Leave approved. The family was notified.'), findsOneWidget);
  });

  testWidgets('a failed decision keeps the request', (tester) async {
    await tester.pumpWidget(screen(decideError: 'This leave request was already approved.'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Nodira Aliyeva asked to be excused'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-leave')));
    await tester.pumpAndSettle();

    expect(find.text('This leave request was already approved.'), findsOneWidget);
    expect(find.textContaining('Nodira Aliyeva asked to be excused'), findsOneWidget);
  });
}
