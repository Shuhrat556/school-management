// what we send TO the server

// POST /api/auth/register
class UserCreateDto {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  UserCreateDto({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'firstName': firstName,
    'lastName': lastName,
  };
}

// POST /api/auth/authenticate
class LoginRequestDto {
  final String email;
  final String password;

  LoginRequestDto({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

// POST /api/auth/refresh
class RefreshTokenRequestDto {
  final String refreshToken;

  RefreshTokenRequestDto({required this.refreshToken});

  Map<String, dynamic> toJson() => {
    'refreshToken': refreshToken,
  };
}

// POST /api/auth/logout
class LogoutRequestDto {
  final String refreshToken;

  LogoutRequestDto({required this.refreshToken});

  Map<String, dynamic> toJson() => {
    'refreshToken': refreshToken,
  };
}

// POST /api/auth/request-email-verification-code
class RequestEmailVerificationCodeRequestDto {
  final String email;

  RequestEmailVerificationCodeRequestDto({required this.email});

  Map<String, dynamic> toJson() => {
    'email': email,
  };
}

// POST /api/auth/verify-email
class VerifyEmailRequestDto {
  final String email;
  final String code;

  VerifyEmailRequestDto({
    required this.email,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'code': code,
  };
}

// POST /api/auth/request-password-reset
class RequestPasswordResetRequestDto {
  final String email;

  RequestPasswordResetRequestDto({required this.email});

  Map<String, dynamic> toJson() => {
    'email': email,
  };
}

// POST /api/auth/reset-password
class ResetPasswordRequestDto {
  final String email;
  final String code;
  final String newPassword;

  ResetPasswordRequestDto({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'code': code,
    'newPassword': newPassword,
  };
}

// POST /api/auth/oauth/google
class GoogleAuthRequestDto {
  final String idToken;

  GoogleAuthRequestDto({required this.idToken});

  Map<String, dynamic> toJson() => {
    'idToken': idToken,
  };
}

// POST /api/auth/oauth/facebook
class FacebookAuthRequestDto {
  final String accessToken;

  FacebookAuthRequestDto({required this.accessToken});

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
  };
}

// what we get BACK from the server

// Registration response: backend returns UserResponseDto (no tokens)
// {id, email, firstName, lastName, role (int), userRole (string), isEmailVerified}
class UserResponseDto {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final int role;
  final String userRole;
  final bool isEmailVerified;

  UserResponseDto({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.userRole,
    required this.isEmailVerified,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserResponseDto.fromJson(Map<String, dynamic> json) {
    return UserResponseDto(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      role: json['role'] is int ? json['role'] : 0,
      userRole: json['userRole'] as String? ?? '',
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }
}

// Login/Authenticate response: backend returns AuthResponseDto (with tokens)
// {userId, firstName, lastName, email, role (int), userRole (string), isActive, isEmailVerified, token, refreshToken, lastLoginAt}
class AuthResponseDto {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final int role;
  final String userRole;
  final bool isActive;
  final bool isEmailVerified;
  final String token; // the short-lived access token (backend calls it "token")
  final String refreshToken;
  final String? lastLoginAt;

  AuthResponseDto({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.userRole,
    required this.isActive,
    required this.isEmailVerified,
    required this.token,
    required this.refreshToken,
    this.lastLoginAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      userId: json['userId']?.toString() ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] is int ? json['role'] : 0,
      userRole: json['userRole'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      lastLoginAt: json['lastLoginAt']?.toString(),
    );
  }
}

// school data — classrooms, students, teachers, grades, etc.

// Student response from GET /api/school/students
class StudentDto {
  final String id;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? dateOfBirth;
  final String? phone;
  final String? address;
  final String? email;
  final bool isActive;
  final String createdAt;

  StudentDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.dateOfBirth,
    this.phone,
    this.address,
    this.email,
    required this.isActive,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory StudentDto.fromJson(Map<String, dynamic> json) {
    return StudentDto(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth']?.toString(),
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      email: json['email'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    if (gender != null) 'gender': gender,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (email != null) 'email': email,
  };
}

// Teacher response from GET /api/school/teachers
class TeacherDto {
  final String id;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? dateOfBirth;
  final String? phone;
  final String? email;
  final String? specialization;
  final bool isActive;
  final String createdAt;

  TeacherDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.dateOfBirth,
    this.phone,
    this.email,
    this.specialization,
    required this.isActive,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory TeacherDto.fromJson(Map<String, dynamic> json) {
    return TeacherDto(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth']?.toString(),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      specialization: json['specialization'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    if (gender != null) 'gender': gender,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (specialization != null) 'specialization': specialization,
  };
}

// Classroom response from GET /api/school/classrooms
class ClassroomDto {
  final String id;
  final String name;
  final String? grade;
  final String? academicYear;
  final String? teacherId;
  final String? teacherName;
  final String? subjectName;
  final bool isActive;
  final String createdAt;
  final int studentCount;

  ClassroomDto({
    required this.id,
    required this.name,
    this.grade,
    this.academicYear,
    this.teacherId,
    this.teacherName,
    this.subjectName,
    required this.isActive,
    required this.createdAt,
    required this.studentCount,
  });

  factory ClassroomDto.fromJson(Map<String, dynamic> json) {
    return ClassroomDto(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      grade: json['grade'] as String?,
      academicYear: json['academicYear'] as String?,
      teacherId: json['teacherId']?.toString(),
      teacherName: json['teacherName'] as String?,
      subjectName: json['subjectName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt']?.toString() ?? '',
      studentCount: json['studentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (grade != null) 'grade': grade,
        if (academicYear != null) 'academicYear': academicYear,
        if (teacherId != null) 'teacherId': teacherId,
      };
}

// Classroom detail (includes student list) from GET /api/school/classrooms/{id}
class ClassroomDetailDto {
  final String id;
  final String name;
  final String? grade;
  final String? academicYear;
  final String? teacherId;
  final String? teacherName;
  final String? subjectId;
  final bool isActive;
  final String createdAt;
  final List<ClassroomStudentDto> students;

  ClassroomDetailDto({
    required this.id,
    required this.name,
    this.grade,
    this.academicYear,
    this.teacherId,
    this.teacherName,
    this.subjectId,
    required this.isActive,
    required this.createdAt,
    required this.students,
  });

  factory ClassroomDetailDto.fromJson(Map<String, dynamic> json) {
    return ClassroomDetailDto(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      grade: json['grade'] as String?,
      academicYear: json['academicYear'] as String?,
      teacherId: json['teacherId']?.toString(),
      teacherName: json['teacherName'] as String?,
      subjectId: json['subjectId']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt']?.toString() ?? '',
      students: (json['students'] as List<dynamic>?)
              ?.map((s) =>
                  ClassroomStudentDto.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Student nested inside ClassroomDetailDto
class ClassroomStudentDto {
  final String studentId;
  final String firstName;
  final String lastName;
  final String enrolledAt;

  ClassroomStudentDto({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.enrolledAt,
  });

  String get fullName => '$firstName $lastName';

  factory ClassroomStudentDto.fromJson(Map<String, dynamic> json) {
    return ClassroomStudentDto(
      studentId: json['studentId']?.toString() ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      enrolledAt: json['enrolledAt']?.toString() ?? '',
    );
  }
}

// wrapper for paginated responses — holds items + total count + page info
class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedResult(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: json['totalCount'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalPages: json['totalPages'] as int? ?? 0,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}

// subjects / courses taught in school

class SubjectDto {
  final String id;
  final String subjectName;
  final bool isActive;
  final String createdAt;
  final List<String> teacherNames;

  SubjectDto({
    required this.id,
    required this.subjectName,
    required this.isActive,
    required this.createdAt,
    required this.teacherNames,
  });

  factory SubjectDto.fromJson(Map<String, dynamic> json) {
    return SubjectDto(
      id: json['id'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      teacherNames: (json['teacherNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {'subjectName': subjectName};
}

// student scores / grades

class GradeDto {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final double score;
  final String semester;
  final String createdAt;

  GradeDto({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.score,
    required this.semester,
    required this.createdAt,
  });

  factory GradeDto.fromJson(Map<String, dynamic> json) {
    return GradeDto(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      semester: json['semester'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'subjectId': subjectId,
    'score': score,
    'semester': semester,
  };
}

// attendance records — who showed up, who was absent, who was late

class AttendanceDto {
  final String id;
  final String studentId;
  final String studentName;
  final String? classroomId;
  final String? classroomName;
  final String date; // date as "YYYY-MM-DD" e.g. "2026-02-24"
  final String status; // "Present", "Absent", or "Late"
  final String createdAt;

  AttendanceDto({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.classroomId,
    this.classroomName,
    required this.date,
    required this.status,
    required this.createdAt,
  });

  factory AttendanceDto.fromJson(Map<String, dynamic> json) {
    return AttendanceDto(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      classroomId: json['classroomId'] as String?,
      classroomName: json['classroomName'] as String?,
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'Present',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AttendanceMarkRequest {
  final String studentId;
  final int status; // 1 = Present, 2 = Absent, 3 = Late

  AttendanceMarkRequest({required this.studentId, required this.status});

  Map<String, dynamic> toJson() => {'studentId': studentId, 'status': status};
}

class BulkMarkAttendanceRequest {
  final String classroomId;
  final String date; // format: "YYYY-MM-DD"
  final List<AttendanceMarkRequest> records;

  BulkMarkAttendanceRequest({
    required this.classroomId,
    required this.date,
    required this.records,
  });

  Map<String, dynamic> toJson() => {
    'classroomId': classroomId,
    'date': date,
    'records': records.map((r) => r.toJson()).toList(),
  };
}

// class schedule — which subject, when, and where

class ScheduleDto {
  final String id;
  final String classroomId;
  final String classroomName;
  final String subjectId;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final String day;
  final String time;

  ScheduleDto({
    required this.id,
    required this.classroomId,
    required this.classroomName,
    required this.subjectId,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.day,
    required this.time,
  });

  static String _timeRange(String? start, String? end) {
    String hhmm(String? t) => t == null || t.length < 5 ? '' : t.substring(0, 5);
    if (start == null) return '';
    return end == null ? hhmm(start) : '${hhmm(start)} - ${hhmm(end)}';
  }

  factory ScheduleDto.fromJson(Map<String, dynamic> json) {
    return ScheduleDto(
      id: json['id'] as String? ?? '',
      classroomId: json['classroomId'] as String? ?? '',
      classroomName: json['classroomName'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      teacherId: json['teacherId'] as String?,
      teacherName: json['teacherName'] as String?,
      // The API sends dayOfWeekName and startTime/endTime ("09:00:00"); day/time were never filled.
      day: json['day'] as String? ?? json['dayOfWeekName'] as String? ?? '',
      time: json['time'] as String? ?? _timeRange(json['startTime'] as String?, json['endTime'] as String?),
    );
  }

}

// in-app notifications — new grades, absences and class announcements

class NotificationDto {
  final String id;
  final String studentId;
  final String studentName;
  final String type; // "Grade", "Attendance" or "Announcement"
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationDto({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['readAt'] as String? ?? '')?.toLocal(),
    );
  }
}

// Google/Facebook accounts linked to the signed-in user (GET /api/auth/logins)

class ExternalLoginsDto {
  final bool hasPassword;
  final List<String> providers; // "Google", "Facebook"

  ExternalLoginsDto({required this.hasPassword, required this.providers});

  bool isLinked(String provider) =>
      providers.any((p) => p.toLowerCase() == provider.toLowerCase());

  factory ExternalLoginsDto.fromJson(Map<String, dynamic> json) {
    return ExternalLoginsDto(
      hasPassword: json['hasPassword'] as bool? ?? false,
      providers: (json['logins'] as List? ?? const [])
          .map((e) => (e as Map<String, dynamic>)['provider'] as String? ?? '')
          .where((p) => p.isNotEmpty)
          .toList(),
    );
  }
}

// class materials; homework is a material of type assignment (GET /api/materials/classroom/{id})

class MaterialDto {
  static const int assignmentType = 2;

  final String id;
  final String classroomId;
  final String title;
  final String? description;
  final String? url;
  final int type;
  final DateTime? dueAt; // local time
  final int submissionCount; // students who handed it in
  final bool isActive;
  final DateTime createdAt;

  MaterialDto({
    required this.id,
    required this.classroomId,
    required this.title,
    this.description,
    this.url,
    required this.type,
    this.dueAt,
    this.submissionCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isAssignment => type == assignmentType;

  factory MaterialDto.fromJson(Map<String, dynamic> json) {
    return MaterialDto(
      id: json['id']?.toString() ?? '',
      classroomId: json['classroomId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      url: json['url'] as String?,
      type: json['type'] as int? ?? 0,
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '')?.toLocal(),
      submissionCount: json['submissionCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

// a student's hand-in for a material (GET /api/submissions/student/{id})

class SubmissionDto {
  final String id;
  final String materialId;
  final String? submissionUrl;
  final DateTime submittedAt;
  final double? grade;
  final String? feedback;

  SubmissionDto({
    required this.id,
    required this.materialId,
    this.submissionUrl,
    required this.submittedAt,
    this.grade,
    this.feedback,
  });

  factory SubmissionDto.fromJson(Map<String, dynamic> json) {
    return SubmissionDto(
      id: json['id']?.toString() ?? '',
      materialId: json['materialId']?.toString() ?? '',
      submissionUrl: json['submissionUrl'] as String?,
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      grade: (json['grade'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
    );
  }
}

// What the teacher's class screen shows about one class right now (BUGS B36)
class ClassSnapshot {
  final List<Map<String, dynamic>> students; // name, id, status, avatar, grade, score
  final MaterialDto? latestHomework;
  final List<String> materials;

  ClassSnapshot({required this.students, this.latestHomework, this.materials = const []});
}

// GET /api/school/Departments — a subject belongs to one department

class DepartmentDto {
  final String id;
  final String name;

  DepartmentDto({required this.id, required this.name});

  factory DepartmentDto.fromJson(Map<String, dynamic> json) => DepartmentDto(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
      );
}

// a request to be excused from classes (GET /api/school/leave-requests/mine)

class LeaveRequestDto {
  final String id;
  final String type; // "Sick", "Personal" or "Other"
  final String startDate; // yyyy-MM-dd
  final String endDate;
  final String reason;
  final String status; // "Pending", "Approved" or "Rejected"
  final String? reviewNote;
  final String studentName;
  final DateTime? createdAt;

  LeaveRequestDto({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.studentName = '',
    this.createdAt,
  });

  factory LeaveRequestDto.fromJson(Map<String, dynamic> json) => LeaveRequestDto(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'Other',
        startDate: json['startDate'] as String? ?? '',
        endDate: json['endDate'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
        reviewNote: json['reviewNote'] as String?,
        studentName: json['studentName'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      );
}

// a parent account linked to a student (GET /api/school/Students/{id}/parents)

class StudentParentDto {
  final String fullName;
  final String? email;
  final String? relationship;

  StudentParentDto({required this.fullName, this.email, this.relationship});

  factory StudentParentDto.fromJson(Map<String, dynamic> json) => StudentParentDto(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String?,
        relationship: json['relationship'] as String?,
      );
}

// a published announcement (GET /api/announcements) — school-wide or for one class

class AnnouncementDto {
  final String id;
  final String title;
  final String body;
  final String? classroomName;
  final String authorName;
  final DateTime publishedAt; // local time
  final bool isPublished; // staff also receive drafts

  AnnouncementDto({
    required this.id,
    required this.title,
    required this.body,
    this.classroomName,
    required this.authorName,
    required this.publishedAt,
    this.isPublished = true,
  });

  factory AnnouncementDto.fromJson(Map<String, dynamic> json) => AnnouncementDto(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        classroomName: json['classroomName'] as String?,
        authorName: json['authorTeacherName'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        isPublished: json['isPublished'] as bool? ?? true,
      );
}

// messages between a teacher and a student or parent (/api/school/messages)

class MessageContactDto {
  final String kind; // "Teacher", "Student" or "Parent"
  final String name;
  final String? context;
  final String? teacherId;
  final String? studentId;
  final String? parentAuthUserId;

  MessageContactDto({required this.kind, required this.name, this.context, this.teacherId, this.studentId, this.parentAuthUserId});

  factory MessageContactDto.fromJson(Map<String, dynamic> json) => MessageContactDto(
        kind: json['kind'] as String? ?? '',
        name: json['name'] as String? ?? '',
        context: json['context'] as String?,
        teacherId: json['teacherId']?.toString(),
        studentId: json['studentId']?.toString(),
        parentAuthUserId: json['parentAuthUserId']?.toString(),
      );
}

class ConversationDto {
  final String id;
  final String title;
  final String? subtitle;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ConversationDto({
    required this.id,
    required this.title,
    this.subtitle,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) => ConversationDto(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? '')?.toLocal(),
        unreadCount: json['unreadCount'] as int? ?? 0,
      );
}

class ChatMessageDto {
  final String id;
  final String senderName;
  final String body;
  final DateTime sentAt;
  final bool isMine;

  ChatMessageDto({required this.id, required this.senderName, required this.body, required this.sentAt, required this.isMine});

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
        id: json['id']?.toString() ?? '',
        senderName: json['senderName'] as String? ?? '',
        body: json['body'] as String? ?? '',
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        isMine: json['isMine'] as bool? ?? false,
      );
}
