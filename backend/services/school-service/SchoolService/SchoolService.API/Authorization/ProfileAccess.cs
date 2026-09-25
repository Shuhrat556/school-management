using System.Security.Claims;
using SchoolService.Application.DTOs.Students;
using SchoolService.Application.DTOs.Teachers;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Authorization;

// Resolves the caller's own school profile and answers "may this caller see
// student X?". Staff see everyone, a student sees only themselves and a parent
// sees the children linked to their account.
public class ProfileAccess
{
    private readonly IStudentService _students;
    private readonly ITeacherService _teachers;
    private readonly IParentService _parents;

    public ProfileAccess(IStudentService students, ITeacherService teachers, IParentService parents)
    {
        _students = students;
        _teachers = teachers;
        _parents = parents;
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
    {
        if (user.IsStaff())
            return true;

        if (user.IsInRole(Roles.Parent))
        {
            var parentId = user.GetAuthUserId();
            return parentId.HasValue && await _parents.IsParentOfAsync(parentId.Value, studentId);
        }

        return (await GetOwnStudentAsync(user))?.Id == studentId;
    }
}
