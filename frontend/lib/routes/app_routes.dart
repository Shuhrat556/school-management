import 'package:flutter/material.dart';
import 'package:tamdansers/Login/forgot_password.dart';
// ─── Screen imports ─────────────────────────────────────────────────────────

// Auth / Login
import 'package:tamdansers/Login/loading.dart';
import 'package:tamdansers/Login/login_as_student.dart';
import 'package:tamdansers/Login/login_as_teacher.dart';
import 'package:tamdansers/Login/register.dart';
import 'package:tamdansers/Login/role.dart';
// Dashboards
import 'package:tamdansers/Screen/Dashboard/student_dashboard.dart';
import 'package:tamdansers/Screen/Dashboard/teacher_dashboard.dart';
// Profile
import 'package:tamdansers/Screen/Edit-Profile/student_edit_profile.dart';
import 'package:tamdansers/Screen/Edit-Profile/teacher_edit_profile.dart';
// Student-role screens
import 'package:tamdansers/Screen/Role_STUDENT/attendance_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/course_student.role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/homework_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/notification_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/permision_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/schedule_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/score_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/add_course_role.dart';
// Teacher-role screens
import 'package:tamdansers/Screen/Role_TEACHER/add_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/announce_to_parents_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/attendance_analysis_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/check_attendance_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/course_learn_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/create_class_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/homework_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/input_score_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/link_parent_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/management_class_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/notifications_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/result_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/schedule_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/student_list_screen.dart';
import 'package:tamdansers/Screen/Role_TEACHER/teacher_list_screen.dart';
// Settings
import 'package:tamdansers/Screen/setting/setting_role_student.dart';

// ─── Route name constants ───────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._(); // prevent instantiation

  // ── Auth ──
  static const splash = '/';
  static const roleSelection = '/role-selection';
  static const loginTeacher = '/login/teacher';
  static const loginStudent = '/login/student';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // ── Dashboards ──
  static const studentDashboard = '/student/dashboard';
  static const teacherDashboard = '/teacher/dashboard';

  // ── Profile ──
  static const studentEditProfile = '/student/edit-profile';
  static const teacherEditProfile = '/teacher/edit-profile';

  // ── Settings ──
  static const studentSettings = '/student/settings';
  static const teacherSettings = '/teacher/settings';

  // ── Student role screens ──
  static const studentAttendance = '/student/attendance';
  static const studentSchedule = '/student/schedule';
  static const studentPermission = '/student/permission';
  static const studentHomework = '/student/homework';
  static const studentScore = '/student/score';
  static const studentCourse = '/student/course';
  static const studentNotification = '/student/notification';

  // ── Teacher role screens ──
  static const teacherAddStudent = '/teacher/add-student';
  static const teacherStudentList = '/teacher/student-list';
  static const teacherTeacherList = '/teacher/teacher-list';
  static const teacherAddCourse = '/teacher/add-course';
  static const teacherCreateClass = '/teacher/create-class';
  static const teacherCourse = '/teacher/course';
  static const teacherSchedule = '/teacher/schedule';
  static const teacherAttendance = '/teacher/attendance';
  static const teacherAttendanceAnalysis = '/teacher/attendance-analysis';
  static const teacherManageClass = '/teacher/manage-class';
  static const teacherScoreInput = '/teacher/score-input';
  static const teacherHomework = '/teacher/homework';
  static const teacherStudentResult = '/teacher/student-result';
  static const teacherAnnounce = '/teacher/announce-parents';
  static const teacherNotifications = '/teacher/notifications';
  static const teacherLinkParent = '/teacher/link-parent';


  static Map<String, WidgetBuilder> get routes => {
    // Auth
    splash: (_) => const SplashScreen(),
    roleSelection: (_) => const RoleSelectionScreen(),
    loginTeacher: (_) => const TeacherLoginScreen(),
    loginStudent: (_) => const StudentLoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),

    // Dashboards
    studentDashboard: (_) => const StudentDashboard(),
    teacherDashboard: (_) => const TeacherDashboard(),

    // Profile
    studentEditProfile: (_) => const StudentEditProfileScreen(),
    teacherEditProfile: (_) => const TeacherEditProfileScreen(),

    // Settings
    studentSettings: (_) => const StudentSettingsScreen(),
    teacherSettings: (_) => const TeacherSettingsScreen(),

    // Student role
    studentAttendance: (_) => const AttendanceDashboard(),
    studentSchedule: (_) => const StudentScheduleScreen(),
    studentPermission: (_) => const StudentPermissionScreen(),
    studentHomework: (_) => const StudentHomeworkScreen(),
    studentScore: (_) => const StudentScoreScreen(),
    studentCourse: (_) => const ClassCourseStudentScreen(),
    studentNotification: (_) => const NotificationScreen(),

    // Teacher role
    teacherAddStudent: (_) => const AddStudentScreen(),
    teacherStudentList: (_) => const StudentListScreen(),
    teacherTeacherList: (_) => const TeacherListScreen(),
    teacherAddCourse: (_) => const AddCourse(),
    teacherCreateClass: (_) => const CreateClassScreen(),
    teacherCourse: (_) => const TeacherCourseScreen(),
    teacherSchedule: (_) => const TeacherScheduleScreen(),
    teacherAttendance: (_) => const AttendanceScreen(),
    teacherAttendanceAnalysis: (_) => const AttendanceAnalysisScreen(),
    teacherManageClass: (_) => const TeacherManagementClassScreen(),
    teacherScoreInput: (_) => const ScoreInputScreen(),
    teacherHomework: (_) => const TeacherHomeworkScreen(),
    teacherStudentResult: (_) => const StudentResultScreen(),
    teacherAnnounce: (_) => const AnnounceToParentsScreen(),
    teacherNotifications: (_) => const TeacherNotificationScreen(),
    teacherLinkParent: (_) => const ParentManagementScreen(),
  };
}
