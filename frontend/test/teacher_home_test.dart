import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Dashboard/teacher_dashboard.dart';
import 'package:tamdansers/services/api_models.dart';

// The teacher home showed sample events; it now shows published announcements (not drafts).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  void ignoreNetworkErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is NetworkImageLoadException) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('events are the published announcements', (tester) async {
    ignoreNetworkErrors();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeacherHomeContent(
          loadAnnouncements: () async => [
            AnnouncementDto(id: 'a1', title: 'Exam week', body: 'Schedule attached', authorName: 'Admin', publishedAt: DateTime(2026, 10, 1)),
            AnnouncementDto(id: 'a2', title: 'Draft notice', body: '...', authorName: 'Me', publishedAt: DateTime(2026, 10, 2), isPublished: false),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Exam week', skipOffstage: false), findsWidgets);
    expect(find.text('Draft notice', skipOffstage: false), findsNothing);
    expect(find.text('Annual Sports Day', skipOffstage: false), findsNothing);
  });

  testWidgets('today\'s classes come from the real timetable', (tester) async {
    ignoreNetworkErrors();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = days[DateTime.now().weekday - 1];
    final tomorrow = days[DateTime.now().weekday % 7];
    ScheduleDto session(String subject, String day, String start, String end) => ScheduleDto.fromJson({
          'id': '$subject$day',
          'classroomId': 'c1',
          'classroomName': 'Physics 8B',
          'subjectId': 's1',
          'subjectName': subject,
          'dayOfWeekName': day,
          'startTime': '$start:00',
          'endTime': '$end:00',
        });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeacherHomeContent(
          loadAnnouncements: () async => [],
          loadSchedule: () async => [session('Physics', today, '09:00', '10:30'), session('Optics', tomorrow, '11:00', '12:00')],
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Physics', skipOffstage: false), findsWidgets);
    expect(find.textContaining('09:00 - 10:30', skipOffstage: false), findsWidgets);
    expect(find.text('Optics', skipOffstage: false), findsNothing); // not today
    expect(find.textContaining('07:00 - 08:00', skipOffstage: false), findsNothing); // the old made-up slot
  });
}
