import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Role_TEACHER/announce_to_parents_role.dart';
import 'package:tamdansers/services/api_models.dart';

ClassroomDto _class(String id, String name) => ClassroomDto.fromJson({
      'id': id,
      'name': name,
      'isActive': true,
      'createdAt': '2026-09-01T00:00:00Z',
      'studentCount': 20,
    });

// BUGS B33: the teacher's "announce to parents" screen said "sent" but sent nothing,
// and offered made-up classes. It now posts a real class announcement.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<String> posted;

  Future<void> openScreen(WidgetTester tester, {String? postError}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnnounceToParentsScreen(
                  loadClasses: () async => [_class('c1', 'Algebra 7A'), _class('c2', 'Physics 8B')],
                  loadLessons: (classroomId) async => classroomId == 'c1' ? ['Quadratic equations'] : [],
                  post: (classroomId, title, body) async {
                    posted.add('$classroomId|$title|$body');
                    return postError;
                  },
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester, {bool withLesson = false}) async {
    await tester.tap(find.text('Select Target Class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Algebra 7A').last);
    await tester.pumpAndSettle();
    if (withLesson) {
      await tester.ensureVisible(find.text('Choose a lesson (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a lesson (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quadratic equations').last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextFormField).at(0), 'Parent meeting');
    await tester.enterText(find.byType(TextFormField).at(1), 'Friday at 5 pm in room 12.');
  }

  setUp(() => posted = []);

  testWidgets('offers the real classes, not sample ones', (tester) async {
    await openScreen(tester);

    await tester.tap(find.text('Select Target Class'));
    await tester.pumpAndSettle();

    expect(find.text('Algebra 7A'), findsWidgets);
    expect(find.text('Grade 10 - Biology'), findsNothing);
  });

  testWidgets('sends the announcement to the chosen class', (tester) async {
    await openScreen(tester);
    await fillForm(tester, withLesson: true);

    await tester.tap(find.byKey(const ValueKey('send-announcement')));
    await tester.pumpAndSettle();

    expect(posted, ['c1|Parent meeting|Friday at 5 pm in room 12.\n\nLesson: Quadratic equations']);
    expect(find.text('open'), findsOneWidget); // back on the previous screen
  });

  testWidgets('stays on the form and shows why when sending fails', (tester) async {
    await openScreen(tester, postError: 'Teachers can only post as themselves.');
    await fillForm(tester);

    await tester.tap(find.byKey(const ValueKey('send-announcement')));
    await tester.pumpAndSettle();

    expect(find.text('Teachers can only post as themselves.'), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });

  testWidgets('a class must be chosen', (tester) async {
    await openScreen(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Parent meeting');
    await tester.enterText(find.byType(TextFormField).at(1), 'Friday at 5 pm in room 12.');

    await tester.tap(find.byKey(const ValueKey('send-announcement')));
    await tester.pumpAndSettle();

    expect(posted, isEmpty);
    expect(find.text('Select a class first.'), findsOneWidget);
  });
}
