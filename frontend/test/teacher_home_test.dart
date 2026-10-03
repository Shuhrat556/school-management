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
}
