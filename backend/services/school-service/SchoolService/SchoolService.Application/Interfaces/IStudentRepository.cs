using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface IStudentRepository
{
    Task<List<Student>> GetAllAsync();
    Task<(List<Student> Items, int TotalCount)> GetPagedAsync(int page, int pageSize);
    Task<Student?> GetByIdAsync(Guid id);
    Task<Student?> GetByAuthUserIdAsync(Guid authUserId);
    Task<Student?> GetUnlinkedByEmailAsync(string email);
    Task AddAsync(Student student);
    Task UpdateAsync(Student student);
    Task DeleteAsync(Student student);
}
