import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_STUDENT/homework_student_role.dart';
import 'package:tamdansers/services/api_models.dart';

// BUGS B34: the student's homework list was made up and "submit" only flipped a local flag.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<String> handedIn;

  Widget screen({Set<String> submitted = const {}, String? submitError}) => MaterialApp(
        home: StudentHomeworkScreen(
          loadClasses: () async => [
            ClassroomDto.fromJson({
              'id': 'c1',
              'name': 'Biology 9A',
              'subjectName': 'Biology',
              'teacherName': 'Ms. Karimova',
              'isActive': true,
              'createdAt': '2026-09-01T00:00:00Z',
              'studentCount': 20,
            }),
          ],
          loadMaterials: (_) async => [
            MaterialDto(
              id: 'h1',
              classroomId: 'c1',
              title: 'Cells worksheet',
              description: 'Pages 10-12',
              type: MaterialDto.assignmentType,
              dueAt: DateTime.now().add(const Duration(days: 5)),
              createdAt: DateTime(2026, 9, 20),
            ),
            MaterialDto(id: 's1', classroomId: 'c1', title: 'Slides', type: 1, createdAt: DateTime(2026, 9, 1)),
          ],
          loadSubmittedIds: () async => submitted,
          submit: (materialId, link) async {
            handedIn.add('$materialId|$link');
            return submitError;
          },
        ),
      );

  Future<void> handIn(WidgetTester tester, String link) async {
    await tester.tap(find.text('Submit Assignment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('upload-work')));
    await tester.tap(find.byKey(const ValueKey('upload-work')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hand-in-link')), link);
    await tester.tap(find.byKey(const ValueKey('hand-in-send')));
    await tester.pumpAndSettle();
  }

  setUp(() => handedIn = []);

  testWidgets('shows the class homework from the API, not sample tasks', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Cells worksheet'), findsOneWidget);
    expect(find.text('Ms. Karimova'), findsOneWidget);
    expect(find.text('Slides'), findsNothing);
    expect(find.text('UNIT 04 • EXERCISE'), findsNothing);
  });

  testWidgets('hands in a link and marks the homework submitted', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await handIn(tester, 'https://drive.example.com/cells');

    expect(handedIn, ['h1|https://drive.example.com/cells']);
    expect(find.text('SUBMITTED'), findsOneWidget);
  });

  testWidgets('a refused hand-in stays pending and shows why', (tester) async {
    await tester.pumpWidget(screen(submitError: 'Material was not found.'));
    await tester.pumpAndSettle();

    await handIn(tester, 'cells.pdf');

    expect(find.text('Material was not found.'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsNothing);
  });

  testWidgets('work handed in earlier shows as submitted', (tester) async {
    await tester.pumpWidget(screen(submitted: {'h1'}));
    await tester.pumpAndSettle();

    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('Review Submission'), findsOneWidget);
  });
}
