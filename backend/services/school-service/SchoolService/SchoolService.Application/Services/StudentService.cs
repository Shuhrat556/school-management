using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Students;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class StudentService : IStudentService
{
    private readonly IStudentRepository _repository;

    public StudentService(IStudentRepository repository)
    {
        _repository = repository;
    }

    public async Task<IReadOnlyList<StudentResponseDto>> GetAllAsync()
    {
        var students = await _repository.GetAllAsync();
        return students
            .Select(MapToResponse)
            .ToList();
    }

    public async Task<PagedResult<StudentResponseDto>> GetAllAsync(int page, int pageSize)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var (items, total) = await _repository.GetPagedAsync(page, pageSize);
        return new PagedResult<StudentResponseDto>
        {
            Items = items.Select(MapToResponse).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<StudentResponseDto> GetByIdAsync(Guid id)
    {
        var student = await _repository.GetByIdAsync(id);
        if (student == null)
            throw new NotFoundException("Student", id);

        return MapToResponse(student);
    }

    public async Task<StudentResponseDto?> GetByAuthUserIdAsync(Guid authUserId)
    {
        var student = await _repository.GetByAuthUserIdAsync(authUserId);
        return student == null ? null : MapToResponse(student);
    }

    // The profile linked to this account; profiles never linked (seed data) match by email.
    public async Task<StudentResponseDto?> GetForUserAsync(Guid authUserId, string? email)
    {
        var student = await _repository.GetByAuthUserIdAsync(authUserId);
        if (student == null && !string.IsNullOrWhiteSpace(email))
            student = await _repository.GetUnlinkedByEmailAsync(email);
        return student == null ? null : MapToResponse(student);
    }

    public async Task<StudentResponseDto> CreateAsync(StudentCreateDto dto)
    {
        var student = new Student(dto.FirstName, dto.LastName);
        student.UpdateBasicInfo(
            dto.FirstName,
            dto.LastName,
            dto.Gender,
            dto.DateOfBirth,
            dto.Phone,
            dto.Address,
            dto.Email);

        if (!dto.IsActive)
            student.Deactivate();

        await _repository.AddAsync(student);
        return MapToResponse(student);
    }

    public async Task<StudentResponseDto> UpdateAsync(Guid id, StudentUpdateDto dto)
    {
        var student = await _repository.GetByIdAsync(id);
        if (student == null)
            throw new NotFoundException("Student", id);

        student.UpdateBasicInfo(
            dto.FirstName,
            dto.LastName,
            dto.Gender,
            dto.DateOfBirth,
            dto.Phone,
            dto.Address,
            dto.Email);

        if (dto.IsActive)
            student.Activate();
        else
            student.Deactivate();

        await _repository.UpdateAsync(student);
        return MapToResponse(student);
    }

    public async Task DeleteAsync(Guid id)
    {
        var student = await _repository.GetByIdAsync(id);
        if (student == null)
            throw new NotFoundException("Student", id);

        await _repository.DeleteAsync(student);
    }

    private static StudentResponseDto MapToResponse(Student s) => new()
    {
        Id = s.Id,
        FirstName = s.FirstName,
        LastName = s.LastName,
        Gender = s.Gender,
        DateOfBirth = s.DateOfBirth,
        Phone = s.Phone,
        Address = s.Address,
        Email = s.Email,
        IsActive = s.IsActive,
        CreatedAt = s.CreatedAt
    };
}
