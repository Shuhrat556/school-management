import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/link_parent_role.dart';
import 'package:tamdansers/services/api_models.dart';

StudentDto _student(String id, String first, String last) =>
    StudentDto.fromJson({'id': id, 'firstName': first, 'lastName': last, 'email': '$first@school.test'});

// The teacher's "Parent Management" form did nothing; it is now a parents directory.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget screen() => MaterialApp(
        home: ParentManagementScreen(
          loadStudents: () async => [_student('s1', 'Nodira', 'Aliyeva'), _student('s2', 'Bekzod', 'Tursunov')],
          loadParents: (studentId) async => studentId == 's1'
              ? [StudentParentDto(fullName: 'Malika Aliyeva', email: 'malika@mail.test', relationship: 'Mother')]
              : [],
        ),
      );

  testWidgets('shows a student\'s linked parents', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nodira Aliyeva'));
    await tester.pumpAndSettle();

    expect(find.text('Malika Aliyeva'), findsOneWidget);
    expect(find.text('Mother · malika@mail.test'), findsOneWidget);
  });

  testWidgets('explains when no parent is linked', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bekzod Tursunov'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No parent account is linked yet'), findsOneWidget);
  });

  testWidgets('search narrows the students', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bek');
    await tester.pumpAndSettle();

    expect(find.text('Bekzod Tursunov'), findsOneWidget);
    expect(find.text('Nodira Aliyeva'), findsNothing);
  });
}
