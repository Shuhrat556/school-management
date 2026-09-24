using System.Security.Claims;
using SchoolService.Application.DTOs.Students;
using SchoolService.Application.DTOs.Teachers;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Authorization;

// Resolves the caller's own school profile and answers "may this caller see
// student X?". Staff see everyone; a student sees only themselves; any other
// role (e.g. Parent, until parent links exist) sees no student data.
public class ProfileAccess
{
    private readonly IStudentService _students;
    private readonly ITeacherService _teachers;

    public ProfileAccess(IStudentService students, ITeacherService teachers)
    {
        _students = students;
        _teachers = teachers;
    }

    public async Task<StudentResponseDto?> GetOwnStudentAsync(ClaimsPrincipal user)
    {
        var authUserId = user.GetAuthUserId();
        if (authUserId == null || !user.IsInRole(Roles.Student))
            return null;
        return await _students.GetForUserAsync(authUserId.Value, user.GetEmail());
    }

    public async Task<TeacherResponseDto?> GetOwnTeacherAsync(ClaimsPrincipal user)
    {
        var authUserId = user.GetAuthUserId();
        if (authUserId == null || !user.IsInRole(Roles.Teacher))
            return null;
        return await _teachers.GetForUserAsync(authUserId.Value, user.GetEmail());
    }

    public async Task<bool> CanAccessStudentAsync(ClaimsPrincipal user, Guid studentId)
        => user.IsStaff() || (await GetOwnStudentAsync(user))?.Id == studentId;
}
