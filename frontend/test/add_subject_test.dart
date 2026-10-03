import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/add_course_role.dart';
import 'package:tamdansers/services/api_models.dart';

// BUGS B37: "Create Course" sent only a name (the API needs a department, so it failed
// silently) and showed a local course with a price that vanished on restart.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<String> created;
  late Object? popped;

  Future<void> open(WidgetTester tester, {String? createError}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddCourse(
                  loadDepartments: () async => [
                    DepartmentDto(id: 'd1', name: 'Natural Sciences'),
                    DepartmentDto(id: 'd2', name: 'Mathematics'),
                  ],
                  create: (name, departmentId, description) async {
                    created.add('$name|$departmentId|$description');
                    return createError;
                  },
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    created = [];
    popped = null;
  });

  testWidgets('creates the subject in the chosen department', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const ValueKey('subject-name')), 'Algebra II');
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-subject')));
    await tester.pumpAndSettle();

    expect(created, ['Algebra II|d2|null']);
    expect(popped, 'Algebra II');
  });

  testWidgets('a department is required', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const ValueKey('subject-name')), 'Algebra II');
    await tester.tap(find.byKey(const ValueKey('create-subject')));
    await tester.pumpAndSettle();

    expect(created, isEmpty);
    expect(find.text('Choose the department this subject belongs to.'), findsOneWidget);
  });

  testWidgets('a refused subject stays on the form with the reason', (tester) async {
    await open(tester, createError: 'A subject with this name already exists.');

    await tester.enterText(find.byKey(const ValueKey('subject-name')), 'Algebra II');
    await tester.tap(find.text('Natural Sciences'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-subject')));
    await tester.pumpAndSettle();

    expect(find.text('A subject with this name already exists.'), findsOneWidget);
    expect(popped, isNull);
  });
}
