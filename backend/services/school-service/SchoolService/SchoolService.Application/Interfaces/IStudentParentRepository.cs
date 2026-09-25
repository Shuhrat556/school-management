using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface IStudentParentRepository
{
    Task<List<StudentParent>> GetByStudentAsync(Guid studentId);
    Task<List<Guid>> GetChildIdsAsync(Guid parentAuthUserId);
    Task<StudentParent?> GetAsync(Guid studentId, Guid parentAuthUserId);
    Task<bool> ExistsAsync(Guid studentId, Guid parentAuthUserId);
    Task AddAsync(StudentParent link);
    Task UpdateAsync(StudentParent link);
    Task DeleteAsync(StudentParent link);
}
