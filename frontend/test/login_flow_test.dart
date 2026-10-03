import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamdansers/Login/login_as_student.dart';
import 'package:tamdansers/Login/login_as_teacher.dart';
import 'package:tamdansers/routes/app_routes.dart';
import 'package:tamdansers/services/api_config.dart';
import 'package:tamdansers/services/api_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, Object?> _auth(int role) => {
      'userId': '00000000-0000-0000-0000-000000000001',
      'firstName': 'Nodira',
      'lastName': 'Aliyeva',
      'email': 'nodira@school.test',
      'role': role,
      'userRole': 'X',
      'isActive': true,
      'isEmailVerified': true,
      'token': 'access',
      'refreshToken': 'refresh',
    };

// The real login screens over a fake backend: password sign-in end to end.
void main() {
  late List<String> requests;
  late FlutterSecureStorage storage;

  ApiService backend({required int role, bool wrongPassword = false}) {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        requests.add('${options.method} ${options.path}');
        if (options.path == ApiConfig.loginEndpoint) {
          return wrongPassword
              ? _json({'message': 'Invalid email or password'}, 401)
              : _json(_auth(role), 200);
        }
        if (options.path.toLowerCase().endsWith('/students/me')) {
          return _json({'id': 'student-42', 'firstName': 'Nodira', 'lastName': 'Aliyeva'}, 200);
        }
        if (options.path.toLowerCase().endsWith('/teachers/me')) {
          return _json({'id': 'teacher-7', 'firstName': 'Anvar', 'lastName': 'Qodirov'}, 200);
        }
        return _json({}, 200);
      });
    return ApiService.withClient(dio, storage);
  }

  Widget app(Widget home) => MaterialApp(
        home: home,
        routes: {
          AppRoutes.studentDashboard: (_) => const Text('student dashboard'),
          AppRoutes.teacherDashboard: (_) => const Text('teacher dashboard'),
        },
      );

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'nodira@school.test');
    await tester.enterText(find.byType(TextField).at(1), 'Password123!');
    await tester.tap(find.byKey(const ValueKey('sign-in')));
    await tester.pumpAndSettle();
  }

  setUp(() => requests = []);

  testWidgets('a student signs in and lands on the student dashboard', (tester) async {
    final api = backend(role: 2);
    await tester.pumpWidget(app(StudentLoginScreen(api: api)));

    await signIn(tester);

    expect(find.text('student dashboard'), findsOneWidget);
    expect(await api.getUserRole(), 'student');
    expect(await storage.read(key: 'entity_id'), 'student-42');
  });

  testWidgets('a wrong password shows the server message', (tester) async {
    await tester.pumpWidget(app(StudentLoginScreen(api: backend(role: 2, wrongPassword: true))));

    await signIn(tester);

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('student dashboard'), findsNothing);
  });

  testWidgets('a teacher account is turned away from the student sign-in', (tester) async {
    final api = backend(role: 1);
    await tester.pumpWidget(app(StudentLoginScreen(api: api)));

    await signIn(tester);

    expect(find.text('student dashboard'), findsNothing);
    expect(find.textContaining('teacher sign-in'), findsOneWidget);
    expect(api.isAuthenticated(), isFalse);
    expect(requests, contains('POST ${ApiConfig.logoutEndpoint}'));
  });

  testWidgets('a student account is turned away from the teacher sign-in', (tester) async {
    final api = backend(role: 2);
    await tester.pumpWidget(app(TeacherLoginScreen(api: api)));

    await signIn(tester);

    expect(find.text('teacher dashboard'), findsNothing);
    expect(find.textContaining('student sign-in'), findsOneWidget);
    expect(api.isAuthenticated(), isFalse);
  });

  testWidgets('a teacher signs in and lands on the teacher dashboard', (tester) async {
    final api = backend(role: 1);
    await tester.pumpWidget(app(TeacherLoginScreen(api: api)));

    await signIn(tester);

    expect(find.text('teacher dashboard'), findsOneWidget);
    expect(await storage.read(key: 'entity_id'), 'teacher-7');
  });
}
