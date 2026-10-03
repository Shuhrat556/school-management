using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Classrooms;

namespace SchoolService.Application.Interfaces;

public interface IClassroomService
{
    Task<IReadOnlyList<ClassroomResponseDto>> GetAllAsync();
    Task<PagedResult<ClassroomResponseDto>> GetAllAsync(int page, int pageSize);
    Task<ClassroomDetailResponseDto> GetByIdAsync(Guid id);
    Task<IReadOnlyList<ClassroomResponseDto>> GetByStudentIdAsync(Guid studentId);
    Task<ClassroomResponseDto> CreateAsync(ClassroomCreateDto dto);
    Task<ClassroomResponseDto> UpdateAsync(Guid id, ClassroomUpdateDto dto);
    Task DeleteAsync(Guid id);
    Task EnrollStudentAsync(Guid classroomId, Guid studentId);
    Task UnenrollStudentAsync(Guid classroomId, Guid studentId);
}
