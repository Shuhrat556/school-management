import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override the backend URL at build/run time instead of editing this file:
  //   flutter run --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:5001
  // Defaults when no override is given:
  //   Android emulator  → http://10.0.2.2:5001
  //   Chrome (debug)    → http://localhost:5001
  //   Web release build → the server the app was loaded from (its nginx
  //                       proxies /api to the gateway)
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (kIsWeb) return kReleaseMode ? Uri.base.origin : 'http://localhost:5001';
    return 'http://10.0.2.2:5001';
  }

  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/authenticate';
  static const String refreshTokenEndpoint = '/api/auth/refresh';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String requestEmailVerificationEndpoint =
      '/api/auth/request-email-verification-code';
  static const String verifyEmailEndpoint = '/api/auth/verify-email';
  static const String requestPasswordResetEndpoint =
      '/api/auth/request-password-reset';
  static const String resetPasswordEndpoint = '/api/auth/reset-password';
  static const String googleAuthEndpoint = '/api/auth/oauth/google';
  static const String facebookAuthEndpoint = '/api/auth/oauth/facebook';

  // School-service endpoints
  static const String studentsEndpoint = '/api/school/Students';
  static const String teachersEndpoint = '/api/school/Teachers';
  static const String classroomsEndpoint = '/api/school/Classrooms';
  static const String subjectsEndpoint = '/api/school/Subjects';
  static const String gradesEndpoint = '/api/school/Grades';
  static const String attendanceEndpoint = '/api/school/Attendance';
  static const String schedulesEndpoint = '/api/school/Schedules';
}
