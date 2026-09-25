using SchoolService.Application.DTOs.Parents;
using SchoolService.Application.DTOs.Students;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class ParentService : IParentService
{
    private readonly IStudentParentRepository _links;
    private readonly IStudentRepository _students;
    private readonly IStudentService _studentService;

    public ParentService(IStudentParentRepository links, IStudentRepository students, IStudentService studentService)
    {
        _links = links;
        _students = students;
        _studentService = studentService;
    }

    public async Task<IReadOnlyList<StudentParentResponseDto>> GetParentsAsync(Guid studentId)
    {
        await EnsureStudentExistsAsync(studentId);
        var links = await _links.GetByStudentAsync(studentId);
        return links.Select(MapToResponse).ToList();
    }

    public async Task<StudentParentResponseDto> LinkAsync(Guid studentId, StudentParentCreateDto dto)
    {
        await EnsureStudentExistsAsync(studentId);

        var link = await _links.GetAsync(studentId, dto.ParentAuthUserId);
        if (link != null)
        {
            link.UpdateDetails(dto.FullName, dto.Email, dto.Relationship);
            await _links.UpdateAsync(link);
        }
        else
        {
            link = new StudentParent(studentId, dto.ParentAuthUserId, dto.FullName, dto.Email, dto.Relationship);
            await _links.AddAsync(link);
        }

        return MapToResponse(link);
    }

    public async Task UnlinkAsync(Guid studentId, Guid parentAuthUserId)
    {
        var link = await _links.GetAsync(studentId, parentAuthUserId)
            ?? throw new NotFoundException($"Parent {parentAuthUserId} is not linked to student {studentId}.");
        await _links.DeleteAsync(link);
    }

    public async Task<IReadOnlyList<StudentResponseDto>> GetChildrenAsync(Guid parentAuthUserId)
    {
        var children = new List<StudentResponseDto>();
        foreach (var studentId in await _links.GetChildIdsAsync(parentAuthUserId))
            children.Add(await _studentService.GetByIdAsync(studentId));
        return children.OrderBy(c => c.FirstName).ThenBy(c => c.LastName).ToList();
    }

    public Task<bool> IsParentOfAsync(Guid parentAuthUserId, Guid studentId)
        => _links.ExistsAsync(studentId, parentAuthUserId);

    private async Task EnsureStudentExistsAsync(Guid studentId)
    {
        if (await _students.GetByIdAsync(studentId) == null)
            throw new NotFoundException("Student", studentId);
    }

    private static StudentParentResponseDto MapToResponse(StudentParent link) => new()
    {
        Id               = link.Id,
        StudentId        = link.StudentId,
        ParentAuthUserId = link.ParentAuthUserId,
        FullName         = link.FullName,
        Email            = link.Email,
        Relationship     = link.Relationship,
        CreatedAt        = link.CreatedAt
    };
}
