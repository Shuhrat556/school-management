import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_STUDENT/schedule_student_role.dart';
import 'package:tamdansers/services/api_models.dart';

// BUGS B44: the API's dayOfWeekName/startTime/endTime were never read (day and time stayed
// empty, so "today" never matched), and the student saw the first class of the whole school.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  ScheduleDto session(String subject, String day) => ScheduleDto.fromJson({
        'id': '$subject-$day',
        'classroomId': 'c-$subject',
        'classroomName': '$subject class',
        'subjectId': 's-$subject',
        'subjectName': subject,
        'teacherName': 'Ms. Karimova',
        'dayOfWeek': 1,
        'dayOfWeekName': day,
        'startTime': '09:00:00',
        'endTime': '10:30:00',
      });

  test('reads the day and time the API sends', () {
    final s = session('Biology', 'Monday');

    expect(s.day, 'Monday');
    expect(s.time, '09:00 - 10:30');
  });

  testWidgets('today\'s sessions from all of the student\'s classes are shown', (tester) async {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final today = days[DateTime.now().weekday - 1];
    await tester.pumpWidget(MaterialApp(
      home: StudentScheduleScreen(
        loadSchedule: () async => [session('Biology', today), session('Chemistry', today)],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Biology', skipOffstage: false), findsWidgets);
    expect(find.text('Chemistry', skipOffstage: false), findsWidgets);
  });
}
