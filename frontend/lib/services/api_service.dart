import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'api_config.dart';
import 'api_models.dart';

final Logger _logger = Logger('ApiService');

class ApiService {
  static final ApiService _instance = ApiService._internal();

  late Dio _dio;
  late FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _refreshToken;

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _secureStorage = const FlutterSecureStorage();
    _initializeDio();
  }

  // A separate instance over a given client (e.g. a fake adapter in tests).
  @visibleForTesting
  ApiService.withClient(Dio dio, FlutterSecureStorage storage) {
    _secureStorage = storage;
    _dio = dio;
    _addAuthInterceptor();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    _addAuthInterceptor();
  }

  void _addAuthInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          // Never refresh for the refresh/logout calls themselves or for a request already retried once.
          final canRefresh = error.response?.statusCode == 401 &&
              _refreshToken != null &&
              options.extra['retried'] != true &&
              options.path != ApiConfig.refreshTokenEndpoint &&
              options.path != ApiConfig.logoutEndpoint;
          if (!canRefresh) return handler.next(error);

          // Sent before another request's refresh finished: just retry with the new token.
          final alreadyRefreshed = options.headers['Authorization'] != 'Bearer $_accessToken';
          if (!alreadyRefreshed && !await _refreshOnce()) return handler.next(error);

          try {
            return handler.resolve(await _dio.request(
              options.path,
              options: Options(
                method: options.method,
                headers: options.headers,
                responseType: options.responseType,
                contentType: options.contentType,
                extra: {...options.extra, 'retried': true},
              ),
              data: options.data,
              queryParameters: options.queryParameters,
            ));
          } on DioException catch (e) {
            return handler.next(e);
          }
        },
      ),
    );
  }

  // save & load tokens so the user stays logged in between sessions

  Future<void> loadTokens() async {
    try {
      _accessToken = await _secureStorage.read(key: 'access_token');
      _refreshToken = await _secureStorage.read(key: 'refresh_token');
    } catch (e) {
      _logger.warning('Error loading tokens: $e');
    }
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await Future.wait([
      _secureStorage.write(key: 'access_token', value: accessToken),
      _secureStorage.write(key: 'refresh_token', value: refreshToken),
    ]);
  }

  bool isAuthenticated() => _accessToken != null && _accessToken!.isNotEmpty;

  // login, register, logout, email verification, and password reset

  // POST /api/auth/register
  // Backend returns UserResponseDto (no tokens).
  // Backend also auto-sends email verification code.
  Future<UserResponseDto?> register(UserCreateDto userDto) async {
    try {
      final response = await _dio.post(
        ApiConfig.registerEndpoint,
        data: userDto.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        return UserResponseDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Registration failed';
        throw Exception(msg);
      }
      rethrow;
    }
    return null;
  }

  // POST /api/auth/authenticate
  // Backend returns AuthResponseDto with {token, refreshToken, ...}.
  Future<AuthResponseDto?> login(LoginRequestDto loginDto) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginEndpoint,
        data: loginDto.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponseDto.fromJson(
          response.data as Map<String, dynamic>,
        );
        // "token" is what the backend calls the access token — a bit confusing but that's how it is
        await _saveTokens(authResponse.token, authResponse.refreshToken);
        return authResponse;
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final data = e.response?.data as Map;
        throw Exception(data['message'] ?? data['error'] ?? 'Login failed');
      }
      rethrow;
    }
    return null;
  }

  // remember the user's role so we know which dashboard to show at startup
  Future<void> saveUserRole(String role) async {
    await _secureStorage.write(key: 'user_role', value: role);
  }

  // Get the saved user role (teacher, student, parent).
  Future<String?> getUserRole() async {
    return await _secureStorage.read(key: 'user_role');
  }

  // save the user's name and email locally after login
  Future<void> saveUserData({
    required String username,
    required String email,
  }) async {
    await Future.wait([
      _secureStorage.write(key: 'user_name', value: username),
      _secureStorage.write(key: 'user_email', value: email),
    ]);
  }

  // read back the saved username from storage
  Future<String?> getUserName() async {
    return await _secureStorage.read(key: 'user_name');
  }

  // read back the saved email from storage
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: 'user_email');
  }

  // Save the school-service entity ID (student or teacher) after login.
  Future<void> saveEntityId(String entityId) async {
    await _secureStorage.write(key: 'entity_id', value: entityId);
  }

  // get that saved student/teacher ID back
  Future<String?> getEntityId() async {
    return await _secureStorage.read(key: 'entity_id');
  }

  // Parallel 401s wait for one refresh: the server rotates refresh tokens, so a
  // second call with the same token would fail (BUGS B26).
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshOnce() =>
      _refreshInFlight ??= _refreshAccessToken().whenComplete(() => _refreshInFlight = null);

  // POST /api/auth/refresh
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.post(
        ApiConfig.refreshTokenEndpoint,
        data: RefreshTokenRequestDto(refreshToken: _refreshToken!).toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponseDto.fromJson(
          response.data as Map<String, dynamic>,
        );
        await _saveTokens(authResponse.token, authResponse.refreshToken);
        return true;
      }
    } on DioException catch (e) {
      _logger.warning('Token refresh error: ${e.message}');
      // Expired or revoked refresh token: the session is over, stop retrying with it.
      if (e.response?.statusCode == 401) await _clearTokens();
    } catch (e) {
      _logger.warning('Token refresh error: $e');
    }
    return false;
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([
      _secureStorage.delete(key: 'access_token'),
      _secureStorage.delete(key: 'refresh_token'),
      _secureStorage.delete(key: 'user_role'),
      _secureStorage.delete(key: 'user_name'),
      _secureStorage.delete(key: 'user_email'),
      _secureStorage.delete(key: 'entity_id'),
    ]);
  }

  // POST /api/auth/logout
  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        await _dio.post(
          ApiConfig.logoutEndpoint,
          data: LogoutRequestDto(refreshToken: _refreshToken!).toJson(),
        );
      }
    } catch (e) {
      _logger.warning('Logout error: $e');
    } finally {
      await _clearTokens();
    }
  }

  // POST /api/auth/request-email-verification-code
  Future<bool> requestEmailVerificationCode(String email) async {
    try {
      final response = await _dio.post(
        ApiConfig.requestEmailVerificationEndpoint,
        data: RequestEmailVerificationCodeRequestDto(email: email).toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Request verification code error: ${e.message}');
    }
    return false;
  }

  // POST /api/auth/verify-email
  Future<bool> verifyEmail(String email, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyEmailEndpoint,
        data: VerifyEmailRequestDto(email: email, code: code).toJson(),
      );
      // Backend returns HTTP 200 with { success: true, ... } on success
      // and HTTP 400 on failure — so just check the status code.
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Verify email error: ${e.message}');
    }
    return false;
  }

  // POST /api/auth/request-password-reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _dio.post(
        ApiConfig.requestPasswordResetEndpoint,
        data: RequestPasswordResetRequestDto(email: email).toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Request password reset error: ${e.message}');
    }
    return false;
  }

  // POST /api/auth/reset-password
  Future<bool> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await _dio.post(
        ApiConfig.resetPasswordEndpoint,
        data: ResetPasswordRequestDto(
          email: email,
          code: code,
          newPassword: newPassword,
        ).toJson(),
      );
      return response.statusCode == 200 && response.data == true;
    } on DioException catch (e) {
      _logger.warning('Reset password error: ${e.message}');
    }
    return false;
  }

  // sign in with Google — sends the Google ID token to the backend
  Future<AuthResponseDto?> authenticateWithGoogle(String idToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.googleAuthEndpoint,
        data: GoogleAuthRequestDto(idToken: idToken).toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponseDto.fromJson(
          response.data as Map<String, dynamic>,
        );
        await _saveTokens(authResponse.token, authResponse.refreshToken);
        return authResponse;
      }
    } on DioException catch (e) {
      _logger.warning('Google auth error: ${e.message}');
    }
    return null;
  }

  // sign in with Facebook — sends the Facebook access token to the backend
  Future<AuthResponseDto?> authenticateWithFacebook(String accessToken) async {
    try {
      final response = await _dio.post(
        ApiConfig.facebookAuthEndpoint,
        data: FacebookAuthRequestDto(accessToken: accessToken).toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final authResponse = AuthResponseDto.fromJson(
          response.data as Map<String, dynamic>,
        );
        await _saveTokens(authResponse.token, authResponse.refreshToken);
        return authResponse;
      }
    } on DioException catch (e) {
      _logger.warning('Facebook auth error: ${e.message}');
    }
    return null;
  }

  // all the classroom and school data calls (students, teachers, attendance, etc.)

  // GET /api/school/Students — returns list or paged result
  Future<List<StudentDto>> getStudents({int? page, int? pageSize}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (pageSize != null) queryParams['pageSize'] = pageSize;

      final response = await _dio.get(
        ApiConfig.studentsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        // Backend returns plain list if no pagination params, PagedResult otherwise
        if (response.data is List) {
          return (response.data as List)
              .map((e) => StudentDto.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map) {
          final paged = PagedResult.fromJson(
            response.data as Map<String, dynamic>,
            StudentDto.fromJson,
          );
          return paged.items;
        }
      }
    } on DioException catch (e) {
      _logger.warning('Get students error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Students/{id}
  Future<StudentDto?> getStudentById(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.studentsEndpoint}/$id');
      if (response.statusCode == 200 && response.data != null) {
        return StudentDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get student by id error: ${e.message}');
    }
    return null;
  }

  // GET /api/school/Students/me — the signed-in student's own record
  Future<StudentDto?> getMyStudent() async {
    try {
      final response = await _dio.get('${ApiConfig.studentsEndpoint}/me');
      if (response.statusCode == 200 && response.data != null) {
        return StudentDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get my student error: ${e.message}');
    }
    return null;
  }

  // POST /api/school/Students
  Future<StudentDto?> createStudent(StudentDto student) async {
    try {
      final response = await _dio.post(
        ApiConfig.studentsEndpoint,
        data: student.toJson(),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        return StudentDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Create student error: ${e.message}');
      if (e.response?.data != null && e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Create student failed');
      }
    }
    return null;
  }

  // GET /api/school/Teachers — returns list or paged result
  Future<List<TeacherDto>> getTeachers({int? page, int? pageSize}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (pageSize != null) queryParams['pageSize'] = pageSize;

      final response = await _dio.get(
        ApiConfig.teachersEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((e) => TeacherDto.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map) {
          final paged = PagedResult.fromJson(
            response.data as Map<String, dynamic>,
            TeacherDto.fromJson,
          );
          return paged.items;
        }
      }
    } on DioException catch (e) {
      _logger.warning('Get teachers error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Teachers/{id}
  Future<TeacherDto?> getTeacherById(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.teachersEndpoint}/$id');
      if (response.statusCode == 200 && response.data != null) {
        return TeacherDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get teacher by id error: ${e.message}');
    }
    return null;
  }

  // GET /api/school/Teachers/me — the signed-in teacher's own record
  Future<TeacherDto?> getMyTeacher() async {
    try {
      final response = await _dio.get('${ApiConfig.teachersEndpoint}/me');
      if (response.statusCode == 200 && response.data != null) {
        return TeacherDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get my teacher error: ${e.message}');
    }
    return null;
  }

  // POST /api/school/Teachers
  Future<TeacherDto?> createTeacher(TeacherDto teacher) async {
    try {
      final response = await _dio.post(
        ApiConfig.teachersEndpoint,
        data: teacher.toJson(),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        return TeacherDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Create teacher error: ${e.message}');
      if (e.response?.data != null && e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Create teacher failed');
      }
    }
    return null;
  }

  // PUT /api/school/Teachers/{id}
  Future<bool> updateTeacher(String id, TeacherDto teacher) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.teachersEndpoint}/$id',
        data: teacher.toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Update teacher error: ${e.message}');
      rethrow;
    }
  }

  // GET /api/school/Classrooms — returns list or paged result
  Future<List<ClassroomDto>> getClassrooms({int? page, int? pageSize}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (pageSize != null) queryParams['pageSize'] = pageSize;

      final response = await _dio.get(
        ApiConfig.classroomsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((e) => ClassroomDto.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map) {
          final paged = PagedResult.fromJson(
            response.data as Map<String, dynamic>,
            ClassroomDto.fromJson,
          );
          return paged.items;
        }
      }
    } on DioException catch (e) {
      _logger.warning('Get classrooms error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Classrooms/{id} — returns detail with students list
  Future<ClassroomDetailDto?> getClassroomDetail(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.classroomsEndpoint}/$id');
      if (response.statusCode == 200 && response.data != null) {
        return ClassroomDetailDto.fromJson(
            response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get classroom detail error: ${e.message}');
    }
    return null;
  }

  // POST /api/school/Classrooms — create a new classroom
  Future<ClassroomDto?> createClassroom(ClassroomDto classroom) async {
    try {
      final response = await _dio.post(
        ApiConfig.classroomsEndpoint,
        data: classroom.toJson(),
      );
      if (response.statusCode == 201 && response.data != null) {
        return ClassroomDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Create classroom error: ${e.message}');
      rethrow;
    }
    return null;
  }

  // POST /api/school/Classrooms/{id}/enroll
  Future<bool> enrollStudent(String classroomId, String studentId) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.classroomsEndpoint}/$classroomId/enroll',
        data: {'studentId': studentId},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Enroll student error: ${e.message}');
    }
    return false;
  }

  // PUT /api/school/Students/{id}
  Future<bool> updateStudent(String id, StudentDto student) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.studentsEndpoint}/$id',
        data: student.toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Update student error: ${e.message}');
      rethrow;
    }
  }

  // DELETE /api/school/Students/{id}
  Future<bool> deleteStudent(String id) async {
    try {
      final response = await _dio.delete('${ApiConfig.studentsEndpoint}/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      _logger.warning('Delete student error: ${e.message}');
      rethrow;
    }
  }

  // subjects (the courses taught in school)

  // GET /api/school/Subjects
  Future<List<SubjectDto>> getSubjects() async {
    try {
      final response = await _dio.get(ApiConfig.subjectsEndpoint);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => SubjectDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get subjects error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Subjects/{id}
  Future<SubjectDto?> getSubjectById(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.subjectsEndpoint}/$id');
      if (response.statusCode == 200) {
        return SubjectDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get subject error: ${e.message}');
    }
    return null;
  }

  // POST /api/school/Subjects
  // A subject needs its department. Null on success, otherwise the reason.
  Future<String?> createSubject({
    required String subjectName,
    required String departmentId,
    String? description,
  }) async {
    try {
      await _dio.post(
        ApiConfig.subjectsEndpoint,
        data: {
          'subjectName': subjectName,
          'departmentId': departmentId,
          if (description != null && description.isNotEmpty) 'description': description,
        },
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Create subject error: ${e.message}');
      return _errorMessage(e, 'Could not create the subject.');
    }
  }

  // GET /api/school/Departments
  Future<List<DepartmentDto>> getDepartments() async {
    try {
      final response = await _dio.get(ApiConfig.departmentsEndpoint);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => DepartmentDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get departments error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/Subjects/{id}/assign-teacher
  Future<bool> assignTeacherToSubject(String subjectId, String teacherId) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.subjectsEndpoint}/$subjectId/assign-teacher',
        data: {'teacherId': teacherId},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Assign teacher error: ${e.message}');
    }
    return false;
  }

  // student scores and report cards

  // get all grade records — can filter by student, subject, or semester
  Future<List<GradeDto>> getGrades({String? studentId, String? subjectId, String? semester}) async {
    try {
      final params = <String, dynamic>{};
      if (studentId != null) params['studentId'] = studentId;
      if (subjectId != null) params['subjectId'] = subjectId;
      if (semester != null) params['semester'] = semester;

      final response = await _dio.get(ApiConfig.gradesEndpoint, queryParameters: params);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => GradeDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get grades error: ${e.message}');
    }
    return [];
  }

  // save a new grade/score for a student
  Future<GradeDto?> createGrade(GradeDto grade) async {
    try {
      final response = await _dio.post(
        ApiConfig.gradesEndpoint,
        data: grade.toJson(),
      );
      if (response.statusCode == 201) {
        return GradeDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Create grade error: ${e.message}');
      rethrow;
    }
    return null;
  }

  // update an existing grade (e.g. teacher corrects an entry)
  Future<bool> updateGrade(String id, double score, String semester) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.gradesEndpoint}/$id',
        data: {'score': score, 'semester': semester},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Update grade error: ${e.message}');
    }
    return false;
  }

  // delete a grade entry
  Future<bool> deleteGrade(String id) async {
    try {
      final response = await _dio.delete('${ApiConfig.gradesEndpoint}/$id');
      return response.statusCode == 204;
    } on DioException catch (e) {
      _logger.warning('Delete grade error: ${e.message}');
    }
    return false;
  }

  // who came to class, who didn't, and who was late

  // GET /api/school/Attendance?classroomId=&date=YYYY-MM-DD
  Future<List<AttendanceDto>> getClassroomAttendance(String classroomId, String date) async {
    try {
      final response = await _dio.get(
        ApiConfig.attendanceEndpoint,
        queryParameters: {'classroomId': classroomId, 'date': date},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get attendance error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Attendance/{studentId}/history
  Future<List<AttendanceDto>> getStudentAttendanceHistory(String studentId) async {
    try {
      final response = await _dio.get('${ApiConfig.attendanceEndpoint}/$studentId/history');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get student attendance error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/Attendance/mark
  Future<bool> markAttendance(BulkMarkAttendanceRequest request) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.attendanceEndpoint}/mark',
        data: request.toJson(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _logger.warning('Mark attendance error: ${e.message}');
      rethrow;
    }
  }
  //Schedules
 

  // GET /api/school/Schedules?classroomId=
  Future<List<ScheduleDto>> getClassroomSchedule(String classroomId) async {
    try {
      final response = await _dio.get(
        ApiConfig.schedulesEndpoint,
        queryParameters: {'classroomId': classroomId},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => ScheduleDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get schedule error: ${e.message}');
    }
    return [];
  }

  // GET /api/school/Schedules?teacherId=
  Future<List<ScheduleDto>> getTeacherSchedule(String teacherId) async {
    try {
      final response = await _dio.get(
        ApiConfig.schedulesEndpoint,
        queryParameters: {'teacherId': teacherId},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => ScheduleDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get teacher schedule error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/Schedules
  Future<ScheduleDto?> createSchedule(ScheduleDto schedule) async {
    try {
      final response = await _dio.post(
        ApiConfig.schedulesEndpoint,
        data: schedule.toJson(),
      );
      if (response.statusCode == 201) {
        return ScheduleDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Create schedule error: ${e.message}');
      rethrow;
    }
    return null;
  }

  // DELETE /api/school/Schedules/{id}
  Future<bool> deleteSchedule(String id) async {
    try {
      final response = await _dio.delete('${ApiConfig.schedulesEndpoint}/$id');
      return response.statusCode == 204;
    } on DioException catch (e) {
      _logger.warning('Delete schedule error: ${e.message}');
    }
    return false;
  }

  // notifications

  // GET /api/school/notifications
  Future<List<NotificationDto>> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.notificationsEndpoint,
        queryParameters: {'unreadOnly': unreadOnly, 'take': 100},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get notifications error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/notifications/{id}/read
  Future<bool> markNotificationRead(String id) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.notificationsEndpoint}/$id/read',
      );
      return response.statusCode == 204;
    } on DioException catch (e) {
      _logger.warning('Mark notification read error: ${e.message}');
    }
    return false;
  }

  // POST /api/school/notifications/read-all
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await _dio.post(
        '${ApiConfig.notificationsEndpoint}/read-all',
      );
      return response.statusCode == 204;
    } on DioException catch (e) {
      _logger.warning('Mark all notifications read error: ${e.message}');
    }
    return false;
  }

  // GET /api/auth/logins — Google/Facebook accounts linked to this user
  Future<ExternalLoginsDto?> getExternalLogins() async {
    try {
      final response = await _dio.get(ApiConfig.externalLoginsEndpoint);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ExternalLoginsDto.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      _logger.warning('Get linked accounts error: ${e.message}');
    }
    return null;
  }

  // POST /api/auth/logins/{google|facebook} — null on success, otherwise the reason
  Future<String?> linkExternalLogin(String provider, String token) async {
    try {
      await _dio.post(
        '${ApiConfig.externalLoginsEndpoint}/$provider',
        data: {'token': token},
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Link $provider error: ${e.message}');
      return _errorMessage(e, 'Could not link the $provider account.');
    }
  }

  // DELETE /api/auth/logins/{google|facebook} — null on success, otherwise the reason
  Future<String?> unlinkExternalLogin(String provider) async {
    try {
      await _dio.delete('${ApiConfig.externalLoginsEndpoint}/$provider');
      return null;
    } on DioException catch (e) {
      _logger.warning('Unlink $provider error: ${e.message}');
      return _errorMessage(e, 'Could not unlink the $provider account.');
    }
  }

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }

  // POST /api/announcements — publishes right away, so the class's students and
  // parents are notified. Null on success, otherwise the reason.
  Future<String?> createAnnouncement({
    required String authorTeacherId,
    required String classroomId,
    required String title,
    required String body,
  }) async {
    try {
      await _dio.post(
        ApiConfig.announcementsEndpoint,
        data: {
          'authorTeacherId': authorTeacherId,
          'classroomId': classroomId,
          'title': title,
          'body': body,
          'publishImmediately': true,
        },
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Create announcement error: ${e.message}');
      return _errorMessage(e, 'Could not send the announcement.');
    }
  }

  // GET /api/materials/classroom/{id} — the class's lessons and assignments
  Future<List<MaterialDto>> getMaterials(String classroomId) async {
    try {
      final response = await _dio.get('${ApiConfig.materialsEndpoint}/classroom/$classroomId');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => MaterialDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get materials error: ${e.message}');
    }
    return [];
  }

  // titles of the class's lessons and assignments
  Future<List<String>> getMaterialTitles(String classroomId) async =>
      (await getMaterials(classroomId)).map((m) => m.title).where((t) => t.isNotEmpty).toList();

  // POST /api/materials — homework for a class; null on success, otherwise the reason
  Future<String?> createAssignment({
    required String classroomId,
    required String title,
    String? description,
    DateTime? dueAt,
  }) async {
    try {
      await _dio.post(
        ApiConfig.materialsEndpoint,
        data: {
          'classroomId': classroomId,
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          'type': MaterialDto.assignmentType,
          if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
        },
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Create assignment error: ${e.message}');
      return _errorMessage(e, 'Could not assign the homework.');
    }
  }

  // GET /api/school/Students/{id}/classrooms — the classes a student is in
  Future<List<ClassroomDto>> getStudentClassrooms(String studentId) async {
    try {
      final response = await _dio.get('${ApiConfig.studentsEndpoint}/$studentId/classrooms');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => ClassroomDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get student classrooms error: ${e.message}');
    }
    return [];
  }

  // GET /api/submissions/student/{id} — a student's hand-ins
  Future<List<SubmissionDto>> getStudentSubmissions(String studentId) async {
    try {
      final response = await _dio.get('/api/submissions/student/$studentId');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => SubmissionDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get submissions error: ${e.message}');
    }
    return [];
  }

  // POST /api/submissions — hand in work as a link or file name; null on success, otherwise the reason
  Future<String?> submitAssignment(String materialId, String link) async {
    try {
      await _dio.post('/api/submissions', data: {'materialId': materialId, 'submissionUrl': link});
      return null;
    } on DioException catch (e) {
      _logger.warning('Submit assignment error: ${e.message}');
      return _errorMessage(e, 'Could not hand in the work.');
    }
  }

  // GET /api/school/leave-requests/mine — the student's (or parent's children's) requests
  Future<List<LeaveRequestDto>> getMyLeaveRequests() async {
    try {
      final response = await _dio.get('${ApiConfig.leaveRequestsEndpoint}/mine');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => LeaveRequestDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get leave requests error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/leave-requests — type 1 sick, 2 personal, 3 other. Null on success, otherwise the reason.
  Future<String?> createLeaveRequest({
    required int type,
    required DateTime startDate,
    DateTime? endDate,
    required String reason,
  }) async {
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await _dio.post(
        ApiConfig.leaveRequestsEndpoint,
        data: {
          'type': type,
          'startDate': day(startDate),
          if (endDate != null) 'endDate': day(endDate),
          'reason': reason,
        },
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Create leave request error: ${e.message}');
      return _errorMessage(e, 'Could not send the request.');
    }
  }

  // GET /api/school/leave-requests?status= — the staff queue
  Future<List<LeaveRequestDto>> getLeaveRequests({String? status}) async {
    try {
      final response = await _dio.get(
        ApiConfig.leaveRequestsEndpoint,
        queryParameters: status == null ? null : {'status': status},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => LeaveRequestDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on DioException catch (e) {
      _logger.warning('Get leave request queue error: ${e.message}');
    }
    return [];
  }

  // POST /api/school/leave-requests/{id}/approve|reject — null on success, otherwise the reason
  Future<String?> decideLeaveRequest(String id, {required bool approve, String? note}) async {
    try {
      await _dio.post(
        '${ApiConfig.leaveRequestsEndpoint}/$id/${approve ? 'approve' : 'reject'}',
        data: {'note': note},
      );
      return null;
    } on DioException catch (e) {
      _logger.warning('Decide leave request error: ${e.message}');
      return _errorMessage(e, 'Could not save the decision.');
    }
  }
}
