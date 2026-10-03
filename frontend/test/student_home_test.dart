import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Controller/activity_list_widget.dart';
import 'package:tamdansers/Controller/announcement_events.dart';
import 'package:tamdansers/Screen/Dashboard/student_dashboard.dart';
import 'package:tamdansers/services/api_models.dart';

// The student home showed sample events ("Annual Sports Day") and a fixed
// "Advanced Mathematics II 75%"; both now come from the API.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({'user_name': 'Nodira'});
  });

  // The header avatar is a network image; tests have no network.
  void ignoreNetworkImages() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is NetworkImageLoadException) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Widget home({List<AnnouncementDto> announcements = const [], List<GradeDto> grades = const []}) => MaterialApp(
        home: Scaffold(
          body: StudentHomeContent(
            loadAnnouncements: () async => announcements,
            loadGrades: () async => List.of(grades),
          ),
        ),
      );

  testWidgets('shows the latest real grade and real announcements', (tester) async {
    ignoreNetworkImages();
    await tester.pumpWidget(home(
      announcements: [
        AnnouncementDto(
          id: 'a1',
          title: 'Parent meeting on Friday',
          body: 'Room 12 at 5 pm',
          classroomName: 'Biology 9A',
          authorName: 'Ms. Karimova',
          publishedAt: DateTime(2026, 10, 1, 9),
        ),
      ],
      grades: [
        GradeDto.fromJson({'id': 'g1', 'subjectName': 'Chemistry', 'score': 81.0, 'semester': 'S1', 'createdAt': '2026-09-01'}),
        GradeDto.fromJson({'id': 'g2', 'subjectName': 'Biology', 'score': 92.0, 'semester': 'S1', 'createdAt': '2026-09-20'}),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Biology', skipOffstage: false), findsWidgets); // progress card and recent activity
    expect(find.text('92%', skipOffstage: false), findsOneWidget);
    expect(find.text('Parent meeting on Friday', skipOffstage: false), findsWidgets);
    expect(find.text('Advanced Mathematics II', skipOffstage: false), findsNothing);
    expect(find.text('Annual Sports Day', skipOffstage: false), findsNothing);
  });

  testWidgets('says so when there are no grades or announcements', (tester) async {
    ignoreNetworkImages();
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    expect(find.text('No grades yet.', skipOffstage: false), findsOneWidget);
    expect(find.text('No announcements yet.', skipOffstage: false), findsOneWidget);
  });

  testWidgets('an announcement opens without breaking the event screen', (tester) async {
    ignoreNetworkImages();
    final event = eventsFromAnnouncements([
      AnnouncementDto(
        id: 'a1',
        title: 'Parent meeting on Friday',
        body: 'Room 12 at 5 pm',
        authorName: 'Ms. Karimova',
        publishedAt: DateTime(2026, 10, 1, 9),
      ),
    ]).single;

    await tester.pumpWidget(MaterialApp(home: EventDetailScreen(event: event)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Posted by', skipOffstage: false), findsOneWidget);
    expect(find.text('Ms. Karimova', skipOffstage: false), findsOneWidget);
  });

  testWidgets('recent activity is the student\'s grades, filtered by subject', (tester) async {
    ignoreNetworkImages();
    final grades = [
      GradeDto.fromJson({'id': 'g1', 'subjectName': 'Chemistry', 'score': 81.0, 'semester': 'S1', 'createdAt': '2026-09-01'}),
      GradeDto.fromJson({'id': 'g2', 'subjectName': 'Biology', 'score': 92.0, 'semester': 'S1', 'createdAt': '2026-09-20'}),
    ];
    await tester.pumpWidget(MaterialApp(home: AllActivityScreen(activities: activitiesFromGrades(grades))));
    await tester.pumpAndSettle();

    expect(find.text('Cell Light Microscopy', skipOffstage: false), findsNothing);
    expect(find.text('Score 81.0 out of 100 for S1.', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Biology').first);
    await tester.pumpAndSettle();

    expect(find.text('Score 81.0 out of 100 for S1.', skipOffstage: false), findsNothing);
    expect(find.text('Score 92.0 out of 100 for S1.', skipOffstage: false), findsOneWidget);
  });
}
