using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Students;

namespace SchoolService.Application.Interfaces;

public interface IStudentService
{
    Task<IReadOnlyList<StudentResponseDto>> GetAllAsync();
    Task<PagedResult<StudentResponseDto>> GetAllAsync(int page, int pageSize);
    Task<StudentResponseDto> GetByIdAsync(Guid id);
    Task<StudentResponseDto?> GetByAuthUserIdAsync(Guid authUserId);
    Task<StudentResponseDto?> GetForUserAsync(Guid authUserId, string? email);
    Task<StudentResponseDto> CreateAsync(StudentCreateDto dto);
    Task<StudentResponseDto> UpdateAsync(Guid id, StudentUpdateDto dto);
    Task DeleteAsync(Guid id);
}

