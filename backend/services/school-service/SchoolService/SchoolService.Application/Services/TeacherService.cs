using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Teachers;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class TeacherService : ITeacherService
{
    private readonly ITeacherRepository _repository;

    public TeacherService(ITeacherRepository repository)
    {
        _repository = repository;
    }

    public async Task<IReadOnlyList<TeacherResponseDto>> GetAllAsync()
    {
        var teachers = await _repository.GetAllAsync();
        return teachers.Select(MapToResponse).ToList();
    }

    public async Task<PagedResult<TeacherResponseDto>> GetAllAsync(int page, int pageSize)
    {
        page     = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var (items, total) = await _repository.GetPagedAsync(page, pageSize);
        return new PagedResult<TeacherResponseDto>
        {
            Items      = items.Select(MapToResponse).ToList(),
            TotalCount = total,
            Page       = page,
            PageSize   = pageSize
        };
    }

    public async Task<IReadOnlyList<TeacherResponseDto>> GetByDepartmentAsync(Guid departmentId)
    {
        var teachers = await _repository.GetByDepartmentAsync(departmentId);
        return teachers.Select(MapToResponse).ToList();
    }

    public async Task<PagedResult<TeacherResponseDto>> GetByDepartmentAsync(Guid departmentId, int page, int pageSize)
    {
        page     = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var (items, total) = await _repository.GetByDepartmentPagedAsync(departmentId, page, pageSize);
        return new PagedResult<TeacherResponseDto>
        {
            Items      = items.Select(MapToResponse).ToList(),
            TotalCount = total,
            Page       = page,
            PageSize   = pageSize
        };
    }

    public async Task<TeacherResponseDto> GetByIdAsync(Guid id)
    {
        var teacher = await _repository.GetByIdAsync(id);
        if (teacher == null) throw new NotFoundException("Teacher", id);
        return MapToResponse(teacher);
    }

    public async Task<TeacherResponseDto?> GetByAuthUserIdAsync(Guid authUserId)
    {
        var teacher = await _repository.GetByAuthUserIdAsync(authUserId);
        return teacher == null ? null : MapToResponse(teacher);
    }

    // The profile linked to this account; profiles never linked (seed data) match by email.
    public async Task<TeacherResponseDto?> GetForUserAsync(Guid authUserId, string? email)
    {
        var teacher = await _repository.GetByAuthUserIdAsync(authUserId);
        if (teacher == null && !string.IsNullOrWhiteSpace(email))
            teacher = await _repository.GetUnlinkedByEmailAsync(email);
        return teacher == null ? null : MapToResponse(teacher);
    }

    public async Task<TeacherResponseDto> CreateAsync(TeacherCreateDto dto)
    {
        var teacher = new Teacher(dto.FirstName, dto.LastName);
        teacher.UpdateBasicInfo(
            dto.FirstName, dto.LastName, dto.Gender, dto.DateOfBirth,
            dto.Phone, dto.Email, dto.Specialization, dto.HireDate);

        await _repository.AddAsync(teacher);
        return MapToResponse(teacher);
    }

    public async Task<TeacherResponseDto> UpdateAsync(Guid id, TeacherUpdateDto dto)
    {
        var teacher = await _repository.GetByIdAsync(id);
        if (teacher == null) throw new NotFoundException("Teacher", id);

        teacher.UpdateBasicInfo(
            dto.FirstName, dto.LastName, dto.Gender, dto.DateOfBirth,
            dto.Phone, dto.Email, dto.Specialization, dto.HireDate);

        if (dto.IsActive) teacher.Activate(); else teacher.Deactivate();

        await _repository.UpdateAsync(teacher);
        return MapToResponse(teacher);
    }

    public async Task DeleteAsync(Guid id)
    {
        var teacher = await _repository.GetByIdAsync(id);
        if (teacher == null) throw new NotFoundException("Teacher", id);
        await _repository.DeleteAsync(teacher);
    }

    private static TeacherResponseDto MapToResponse(Teacher t) => new()
    {
        Id             = t.Id,
        FirstName      = t.FirstName,
        LastName       = t.LastName,
        Gender         = t.Gender,
        DateOfBirth    = t.DateOfBirth,
        Phone          = t.Phone,
        Email          = t.Email,
        Specialization = t.Specialization,
        HireDate       = t.HireDate,
        IsActive       = t.IsActive,
        CreatedAt      = t.CreatedAt,
        Departments    = t.TeacherDepartments
            .Select(td => new TeacherDepartmentResponseDto
            {
                DepartmentId = td.DepartmentId,
                DepartmentName = td.Department.Name
            })
            .ToList()
    };
}
