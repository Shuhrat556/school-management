import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// Roles as the auth service numbers them.
const _roleNames = {1: 'teacher', 2: 'student', 3: 'parent', 4: 'administrator'};

// Which accounts each sign-in screen accepts: the student app is for students,
// the teacher app for staff (admins keep the access they had).
const _allowedRoles = {
  'student': {2},
  'teacher': {1, 4},
};

// Finishes a successful sign-in (password, Google or Facebook) on the [screen]
// ("student" or "teacher") login: remembers the user and their school record.
// Returns null when the account belongs on this screen; otherwise the session is
// ended again and the message to show is returned.
Future<String?> finishSignIn(ApiService api, AuthResponseDto response, {required String screen}) async {
  if (!(_allowedRoles[screen] ?? const <int>{}).contains(response.role)) {
    await api.logout();
    if (response.role == 3) return 'Parent accounts use the school web portal.';
    final role = _roleNames[response.role] ?? 'different';
    final other = screen == 'student' ? 'teacher' : 'student';
    return 'This is a $role account. Please use the $other sign-in.';
  }

  await api.saveUserRole(screen);
  await api.saveUserData(username: response.fullName, email: response.email);
  // Clear any stale entity_id from a previous session BEFORE lookup, so a failed
  // lookup leaves an empty id instead of someone else's.
  await api.saveEntityId('');
  try {
    final (id, name) = screen == 'student'
        ? await api.getMyStudent().then((s) => (s?.id, s?.fullName))
        : await api.getMyTeacher().then((t) => (t?.id, t?.fullName));
    if (id != null && name != null) {
      await api.saveEntityId(id);
      // Show the school record's name rather than the auth username
      await api.saveUserData(username: name, email: response.email);
    }
  } catch (_) {}
  return null;
}
