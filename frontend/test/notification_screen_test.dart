import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_STUDENT/notification_student_role.dart';
import 'package:tamdansers/services/api_models.dart';

NotificationDto _dto(String id, String type, String title, {bool read = false}) =>
    NotificationDto(
      id: id,
      studentId: 's1',
      studentName: 'Nodira Aliyeva',
      type: type,
      title: title,
      body: '$title body',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      readAt: read ? DateTime.now() : null,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows notifications from the API and filters by type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(
          fetch: () async => [
            _dto('1', 'Grade', 'New grade in Chemistry'),
            _dto('2', 'Attendance', 'Marked absent', read: true),
          ],
          markRead: (_) async => true,
          markAllRead: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New grade in Chemistry'), findsOneWidget);
    expect(find.text('Marked absent'), findsOneWidget);

    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();

    expect(find.text('New grade in Chemistry'), findsOneWidget);
    expect(find.text('Marked absent'), findsNothing);
  });

  testWidgets('mark all read asks the API once', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(
          fetch: () async => [_dto('1', 'Announcement', 'New announcement: Trip')],
          markRead: (_) async => true,
          markAllRead: () async {
            calls++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
