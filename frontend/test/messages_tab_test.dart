import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Dashboard/student_dashboard.dart';
import 'package:tamdansers/Screen/Dashboard/teacher_dashboard.dart';

// BUGS B42: both apps had a Messages tab with sample chats whose "sent" messages reached no one.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the teacher tab says messaging is not available and offers announcements', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TeacherMessagesTab())));

    expect(find.text("Messaging isn't available yet"), findsOneWidget);
    expect(find.text('Post an announcement'), findsOneWidget);
    expect(find.text("John Doe (Parent)"), findsNothing);
  });

  testWidgets('the student tab points to notifications and leave requests', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StudentMessagesTab())));

    expect(find.text("Messaging isn't available yet"), findsOneWidget);
    expect(find.text('Ask for leave'), findsOneWidget);
  });
}
