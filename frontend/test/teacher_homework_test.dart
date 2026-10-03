import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/homework_role.dart';
import 'package:tamdansers/services/api_models.dart';

ClassroomDto _class(String id, String name, int students) => ClassroomDto.fromJson({
      'id': id,
      'name': name,
      'subjectName': 'Biology',
      'isActive': true,
      'createdAt': '2026-09-01T00:00:00Z',
      'studentCount': students,
    });

MaterialDto _homework(String id, String classroomId, String title, {DateTime? due, int handedIn = 0, DateTime? created}) => MaterialDto(
      id: id,
      classroomId: classroomId,
      title: title,
      type: MaterialDto.assignmentType,
      dueAt: due,
      submissionCount: handedIn,
      createdAt: created ?? DateTime(2026, 9, 20),
    );

// BUGS B34: the homework manager showed made-up homework and "assigned" nothing.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<MaterialDto> materials;
  late List<String> assigned;

  Widget screen() => MaterialApp(
        home: TeacherHomeworkScreen(
          loadClasses: () async => [_class('c1', 'Biology 9A', 20), _class('c2', 'Empty class', 0)],
          loadMaterials: (classroomId) async => materials.where((m) => m.classroomId == classroomId).toList(),
          assign: (classroomId, title, description, dueAt) async {
            assigned.add('$classroomId|$title|$description|${dueAt != null}');
            materials.add(_homework('new', classroomId, title, created: DateTime.now()));
            return null;
          },
        ),
      );

  setUp(() {
    assigned = [];
    materials = [
      _homework('h1', 'c1', 'Cells worksheet', due: DateTime.now().add(const Duration(days: 5)), handedIn: 12),
      _homework('h2', 'c1', 'Microscope lab', due: DateTime.now().subtract(const Duration(days: 1)), handedIn: 3),
      _homework('h3', 'c2', 'Reading', handedIn: 0),
      MaterialDto(id: 's1', classroomId: 'c1', title: 'Slides week 1', type: 1, createdAt: DateTime(2026, 9, 1)),
    ];
  });

  testWidgets('lists the classes homework with hand-in counts, not sample data', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Cells worksheet'), findsOneWidget);
    expect(find.text('12 / 20'), findsOneWidget);
    expect(find.text('Slides week 1'), findsNothing); // only assignments are homework
    expect(find.text('Math Problem Set #5'), findsNothing);

    // A class with no students does not break the list
    await tester.enterText(find.byType(TextField).first, 'Reading');
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsWidgets);
    expect(find.text('0 / 0'), findsOneWidget);
  });

  testWidgets('past-due homework is overdue', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overdue').last);
    await tester.pumpAndSettle();

    expect(find.text('Microscope lab'), findsOneWidget);
    expect(find.text('Cells worksheet'), findsNothing);
  });

  testWidgets('assigns homework to a real class and shows it', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Photosynthesis questions');
    await tester.enterText(find.byType(TextField).at(2), 'Answer 1-5');
    await tester.ensureVisible(find.byKey(const ValueKey('assign-homework')));
    await tester.tap(find.byKey(const ValueKey('assign-homework')));
    await tester.pumpAndSettle();

    expect(assigned, ['c1|Photosynthesis questions|Answer 1-5|false']);
    expect(find.text('Photosynthesis questions'), findsOneWidget);
  });
}
