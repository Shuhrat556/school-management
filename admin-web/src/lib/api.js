// All fetch calls go through Next.js rewrites → API Gateway → backend service
// Token is read from localStorage on every call so it's always fresh

function getToken() {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('token');
}

function getRefreshToken() {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('refreshToken');
}

// Several requests can get a 401 at the same moment. The server rotates refresh
// tokens (each one works once), so they must share a single refresh call —
// otherwise the second call uses a spent token and the user is signed out.
let refreshInFlight = null;

function refreshAccessToken() {
  refreshInFlight ??= requestNewAccessToken().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

async function requestNewAccessToken() {
  try {
    const refreshRes = await fetch('/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: getRefreshToken() }),
    });

    if (!refreshRes.ok) {
      console.error(`Token refresh failed with status ${refreshRes.status}`);
      return null;
    }

    const data = await refreshRes.json();
    const token = data?.accessToken ?? data?.token;
    if (!token) throw new Error('Invalid refresh response: missing token');

    localStorage.setItem('token', token);
    if (data.refreshToken) localStorage.setItem('refreshToken', data.refreshToken);
    return token;
  } catch (err) {
    console.error('Token refresh failed', err);
    return null;
  }
}

async function request(path, options = {}) {
  let token = getToken();
  let res = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

  if (res.status === 401) {
    const refreshToken = getRefreshToken();
    const userString = typeof window !== 'undefined' ? localStorage.getItem('user') : null;
    let user = null;
    try { user = JSON.parse(userString); } catch {}

    if (token && refreshToken && user?.email) {
      token = await refreshAccessToken();
      if (token) {
        // Retry original request
        return fetch(path, {
          ...options,
          headers: {
            'Content-Type': 'application/json',
            ...options.headers,
            Authorization: `Bearer ${token}`,
          },
        });
      }
    }

    if (typeof window !== 'undefined') {
      localStorage.removeItem('token');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return res;
  }

  return res;
}

function toDayOfWeekNumber(value) {
  if (typeof value === 'number') return value;

  const dayMap = {
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
    sunday: 7,
  };

  return dayMap[String(value).toLowerCase()] ?? 1;
}

function addMinutes(time, minutes) {
  if (!time || !time.includes(':')) return '09:00';

  const [hours, mins] = time.split(':').map(Number);
  const totalMinutes = (hours * 60) + mins + minutes;
  const nextHours = String(Math.floor((totalMinutes % (24 * 60)) / 60)).padStart(2, '0');
  const nextMinutes = String(totalMinutes % 60).padStart(2, '0');
  return `${nextHours}:${nextMinutes}`;
}

export async function login(email, password) {
  return fetch('/api/auth/authenticate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
}

export async function registerUser(data) {
  return fetch('/api/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

export async function requestEmailVerification(email) {
  return fetch('/api/auth/request-email-verification-code', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });
}

export async function verifyEmail(email, code) {
  return fetch('/api/auth/verify-email', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, code }),
  });
}

export async function requestPasswordReset(email) {
  return fetch('/api/auth/request-password-reset', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
  });
}

export async function resetPassword(email, resetCode, newPassword) {
  return fetch('/api/auth/reset-password', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, resetCode, newPassword }),
  });
}

export async function oauthLogin(provider, token) {
  return fetch(`/api/auth/oauth/${provider}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token }),
  });
}

export async function logoutUser() {
  const t = getToken();
  const refreshToken = getRefreshToken();
  return fetch('/api/auth/logout', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(t ? { Authorization: `Bearer ${t}` } : {}),
    },
    body: JSON.stringify({ refreshToken }),
  });
}

// Teachers

export async function getTeachers(page = 1, pageSize = 20, departmentId = null) {
  let url = `/api/school/teachers?page=${page}&pageSize=${pageSize}`;
  if (departmentId) {
    url += `&departmentId=${departmentId}`;
  }
  const res = await request(url);
  return res.ok ? res.json() : null;
}

export async function getTeacher(id) {
  const res = await request(`/api/school/teachers/${id}`);
  return res.ok ? res.json() : null;
}

export async function createTeacher(data) {
  return request('/api/school/teachers', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateTeacher(id, data) {
  return request(`/api/school/teachers/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export async function deleteTeacher(id) {
  return request(`/api/school/teachers/${id}`, { method: 'DELETE' });
}

//Classrooms

export async function getClassrooms(page = 1, pageSize = 20) {
  const res = await request(`/api/school/classrooms?page=${page}&pageSize=${pageSize}`);
  return res.ok ? res.json() : null;
}

export async function getClassroom(id) {
  const res = await request(`/api/school/classrooms/${id}`);
  return res.ok ? res.json() : null;
}

export async function createClassroom(data) {
  return request('/api/school/classrooms', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateClassroom(id, data) {
  const payload = {
    name: data.name,
    grade: data.grade,
    academicYear: data.academicYear,
    semester: data.semester,
    roomId: data.roomId,
    teacherId: data.teacherId,
    subjectId: data.subjectId,
    isActive: data.isActive,
  };
  return request(`/api/school/classrooms/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

export async function deleteClassroom(id) {
  return request(`/api/school/classrooms/${id}`, { method: 'DELETE' });
}

export async function enrollStudent(classroomId, studentId) {
  return request(`/api/school/classrooms/${classroomId}/enroll`, {
    method: 'POST',
    body: JSON.stringify({ studentId }),
  });
}

export async function unenrollStudent(classroomId, studentId) {
  return request(`/api/school/classrooms/${classroomId}/unenroll/${studentId}`, {
    method: 'DELETE',
  });
}

//Students

export async function getStudents(page = 1, pageSize = 20) {
  const res = await request(`/api/school/students?page=${page}&pageSize=${pageSize}`);
  return res.ok ? res.json() : null;
}

export async function getStudent(id) {
  const res = await request(`/api/school/students/${id}`);
  return res.ok ? res.json() : null;
}

export async function getStudentByAuthUserId(authUserId) {
  const res = await request(`/api/school/students/by-auth-user/${authUserId}`);
  return res.ok ? res.json() : null;
}

// The signed-in student's own profile (linked account, or matched by email)
export async function getMyStudent() {
  const res = await request('/api/school/students/me');
  return res.ok ? res.json() : null;
}

// Parent links (admin manages them; a parent reads their own children)
export async function getStudentParents(studentId) {
  const res = await request(`/api/school/students/${studentId}/parents`);
  return res.ok ? res.json() : null;
}

export async function linkStudentParent(studentId, data) {
  return request(`/api/school/students/${studentId}/parents`, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function unlinkStudentParent(studentId, parentAuthUserId) {
  return request(`/api/school/students/${studentId}/parents/${parentAuthUserId}`, { method: 'DELETE' });
}

// In-app notifications (students and parents)
export async function getNotifications({ unreadOnly = false, take = 50 } = {}) {
  const res = await request(`/api/school/notifications?unreadOnly=${unreadOnly}&take=${take}`);
  return res.ok ? res.json() : null;
}

export async function getUnreadNotificationCount() {
  const res = await request('/api/school/notifications/unread-count');
  if (!res.ok) return 0;
  const data = await res.json();
  return data?.count ?? 0;
}

export async function markNotificationRead(id) {
  return request(`/api/school/notifications/${id}/read`, { method: 'POST' });
}

export async function markAllNotificationsRead() {
  return request('/api/school/notifications/read-all', { method: 'POST' });
}

export async function getMyChildren() {
  const res = await request('/api/school/parents/me/children');
  return res.ok ? res.json() : null;
}

export async function getStudentClassrooms(studentId) {
  const res = await request(`/api/school/students/${studentId}/classrooms`);
  return res.ok ? res.json() : null;
}

export async function createStudent(data) {
  return request('/api/school/students', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateStudent(id, data) {
  return request(`/api/school/students/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export async function deleteStudent(id) {
  return request(`/api/school/students/${id}`, { method: 'DELETE' });
}

//Health

export async function getHealthDashboard() {
  const res = await request('/api/servicehealth/dashboard');
  return res.ok ? res.json() : null;
}

//Subjects

export async function getSubjects(departmentId = null) {
  let url = '/api/school/subjects';
  if (departmentId) {
    url += `?departmentId=${departmentId}`;
  }
  const res = await request(url);
  return res.ok ? res.json() : null;
}

export async function getSubject(id) {
  const res = await request(`/api/school/subjects/${id}`);
  return res.ok ? res.json() : null;
}

export async function createSubject(subject) {
  return request('/api/school/subjects', {
    method: 'POST',
    body: JSON.stringify(subject),
  });
}

export async function updateSubject(id, subject) {
  return request(`/api/school/subjects/${id}`, {
    method: 'PUT',
    body: JSON.stringify(subject),
  });
}

export async function deleteSubject(id) {
  return request(`/api/school/subjects/${id}`, { method: 'DELETE' });
}

export async function assignTeacherToSubject(subjectId, teacherId) {
  return request(`/api/school/subjects/${subjectId}/assign-teacher`, {
    method: 'POST',
    body: JSON.stringify({ teacherId }),
  });
}

export async function removeTeacherFromSubject(subjectId, teacherId) {
  return request(`/api/school/subjects/${subjectId}/remove-teacher/${teacherId}`, {
    method: 'DELETE',
  });
}

//Grades

export async function getGrades({ studentId, subjectId, semester } = {}) {
  const params = new URLSearchParams();
  if (studentId) params.set('studentId', studentId);
  if (subjectId) params.set('subjectId', subjectId);
  if (semester) params.set('semester', semester);
  const res = await request(`/api/school/grades?${params}`);
  return res.ok ? res.json() : null;
}

export async function createGrade(data) {
  return request('/api/school/grades', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function deleteGrade(id) {
  return request(`/api/school/grades/${id}`, { method: 'DELETE' });
}

// Grade audit trail, newest first (Admin only)
export async function getGradeChanges({ studentId, take = 50 } = {}) {
  const params = new URLSearchParams({ take: String(take) });
  if (studentId) params.set('studentId', studentId);
  const res = await request(`/api/school/grades/changes?${params}`);
  return res.ok ? res.json() : null;
}

//Attendance

export async function getAttendance({ classroomId, studentId, date } = {}) {
  if (studentId && !classroomId && !date) {
    return getStudentAttendanceHistory(studentId);
  }

  if (!classroomId || !date) return [];

  const params = new URLSearchParams();
  if (classroomId) params.set('classroomId', classroomId);
  if (date) params.set('date', date);
  const res = await request(`/api/school/attendance?${params}`);
  return res.ok ? res.json() : null;
}

export async function getStudentAttendanceHistory(studentId) {
  const res = await request(`/api/school/attendance/${studentId}/history`);
  return res.ok ? res.json() : null;
}

export async function createAttendance(data) {
  const payload = data?.records
    ? data
    : {
        classroomId: data.classroomId,
        date: data.date,
        records: [
          {
            studentId: data.studentId,
            status:
              data.status === 'Absent'
                ? 2
                : data.status === 'Late'
                  ? 3
                  : 1,
          },
        ],
      };

  return request('/api/school/attendance/mark', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

//Schedules

export async function getClassroomSchedule(classroomId) {
  const res = await request(`/api/school/schedules?classroomId=${classroomId}`);
  return res.ok ? res.json() : null;
}

export async function getTeacherSchedule(teacherId) {
  const res = await request(`/api/school/schedules?teacherId=${teacherId}`);
  return res.ok ? res.json() : null;
}

export async function createSchedule(data) {
  const payload =
    typeof data?.dayOfWeek === 'string' || data?.time
      ? {
          classroomId: data.classroomId,
          subjectId: data.subjectId,
          teacherId: data.teacherId || null,
          dayOfWeek: toDayOfWeekNumber(data.dayOfWeek),
          startTime: data.time ?? '08:00',
          endTime: data.endTime ?? addMinutes(data.time ?? '08:00', 60),
          type: data.type ?? 1,
        }
      : data;

  return request('/api/school/schedules', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function deleteSchedule(id) {
  return request(`/api/school/schedules/${id}`, { method: 'DELETE' });
}

// Departments

export async function getDepartments() {
  const res = await request('/api/school/departments');
  return res.ok ? res.json() : null;
}

export async function getDepartment(id) {
  const res = await request(`/api/school/departments/${id}`);
  return res.ok ? res.json() : null;
}

export async function getDepartmentDetail(id) {
  const res = await request(`/api/school/departments/${id}/detail`);
  return res.ok ? res.json() : null;
}

export async function createDepartment(data) {
  return request('/api/school/departments', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateDepartment(id, data) {
  return request(`/api/school/departments/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export async function deleteDepartment(id) {
  return request(`/api/school/departments/${id}`, { method: 'DELETE' });
}

export async function assignTeacherToDepartment(teacherId, departmentId) {
  return request(`/api/school/departments/${departmentId}/assign-teacher/${teacherId}`, {
    method: 'POST',
  });
}

export async function removeTeacherFromDepartment(teacherId, departmentId) {
  return request(`/api/school/teachers/${teacherId}/departments/${departmentId}`, {
    method: 'DELETE',
  });
}

//Admin — Auth Accounts

export async function getRooms() {
  const res = await request('/api/rooms');
  return res.ok ? res.json() : null;
}

export async function getRoom(id) {
  const res = await request(`/api/rooms/${id}`);
  return res.ok ? res.json() : null;
}

export async function createRoom(data) {
  return request('/api/rooms', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updateRoom(id, data) {
  return request(`/api/rooms/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  });
}

export async function deleteRoom(id) {
  return request(`/api/rooms/${id}`, { method: 'DELETE' });
}

export async function getAnnouncements(classroomId) {
  const suffix = classroomId ? `?classroomId=${classroomId}` : '';
  const res = await request(`/api/announcements${suffix}`);
  return res.ok ? res.json() : null;
}

export async function getMaterialsByClassroom(classroomId) {
  const res = await request(`/api/materials/classroom/${classroomId}`);
  return res.ok ? res.json() : null;
}

export async function getMaterialSubmissions(materialId) {
  const res = await request(`/api/submissions/material/${materialId}`);
  return res.ok ? res.json() : null;
}

export async function getStudentSubmissions(studentId) {
  const res = await request(`/api/submissions/student/${studentId}`);
  return res.ok ? res.json() : null;
}

export async function submitStudentSubmission(studentId, data) {
  return request(`/api/submissions/${studentId}/submit`, {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function changePassword(data) {
  return request('/api/auth/change-password', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function adminGetUsers() {
  const res = await request('/api/auth/admin/users');
  return res?.ok ? res.json() : null;
}

export async function adminCreateUser(data) {
  return request('/api/auth/admin/users', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function adminDeleteUser(id) {
  return request(`/api/auth/admin/users/${id}`, { method: 'DELETE' });
}

export async function adminUpdateUserRole(id, role) {
  return request(`/api/auth/admin/users/${id}/role`, {
    method: 'PATCH',
    body: JSON.stringify({ role }),
  });
}

export async function adminSyncProfile(authUserId, firstName, lastName, role) {
  return request('/api/school/admin/sync-profile', {
    method: 'POST',
    body: JSON.stringify({ authUserId, firstName, lastName, role }),
  });
}
