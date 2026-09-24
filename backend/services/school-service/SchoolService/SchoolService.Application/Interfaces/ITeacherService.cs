using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Teachers;

namespace SchoolService.Application.Interfaces;

public interface ITeacherService
{
    Task<IReadOnlyList<TeacherResponseDto>> GetAllAsync();
    Task<PagedResult<TeacherResponseDto>> GetAllAsync(int page, int pageSize);
    Task<IReadOnlyList<TeacherResponseDto>> GetByDepartmentAsync(Guid departmentId);
    Task<PagedResult<TeacherResponseDto>> GetByDepartmentAsync(Guid departmentId, int page, int pageSize);
    Task<TeacherResponseDto> GetByIdAsync(Guid id);
    Task<TeacherResponseDto?> GetByAuthUserIdAsync(Guid authUserId);
    Task<TeacherResponseDto> CreateAsync(TeacherCreateDto dto);
    Task<TeacherResponseDto> UpdateAsync(Guid id, TeacherUpdateDto dto);
    Task DeleteAsync(Guid id);
}
