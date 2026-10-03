import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/schedule_detail_role.dart';
import 'package:tamdansers/services/api_models.dart';

// BUGS B36: the class screen listed made-up students ("Alexander Pong") with fake
// attendance and scores, and a hard-coded "5 / N" hand-in count.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget screen() => MaterialApp(
        home: TeacherScheduleDetailScreen(
          classData: const {'title': 'Biology', 'time': '09:00', 'room': '12', 'classroomId': 'c1', 'students': 25},
          loadClass: (classroomId) async => ClassSnapshot(
            students: [
              {'name': 'Nodira Aliyeva', 'id': 'AB12CD34', 'status': 'Present', 'avatar': 'N', 'grade': 'A', 'score': 93},
              {'name': 'Bekzod Tursunov', 'id': 'EF56GH78', 'status': 'Not marked', 'avatar': 'B', 'grade': null, 'score': null},
            ],
            latestHomework: MaterialDto(
              id: 'h1',
              classroomId: classroomId,
              title: 'Cells worksheet',
              type: MaterialDto.assignmentType,
              submissionCount: 1,
              createdAt: DateTime(2026, 9, 20),
            ),
          ),
        ),
      );

  testWidgets('the overview counts the real class', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('1 / 2', skipOffstage: false), findsOneWidget);
    expect(find.text('2 students', skipOffstage: false), findsOneWidget);
    expect(find.text('Cells worksheet', skipOffstage: false), findsOneWidget);
    expect(find.text('Due Tomorrow', skipOffstage: false), findsNothing);
  });

  testWidgets('attendance figures come from the real roster', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // One present, one not marked yet: 50 %, and no made-up students anywhere
    expect(find.text('50%', skipOffstage: false), findsOneWidget);
    expect(find.text('Alexander Pong', skipOffstage: false), findsNothing);
  });
}
