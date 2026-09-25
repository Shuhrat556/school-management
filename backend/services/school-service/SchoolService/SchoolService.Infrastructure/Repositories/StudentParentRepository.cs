using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class StudentParentRepository : IStudentParentRepository
{
    private readonly SchoolDbContext _context;

    public StudentParentRepository(SchoolDbContext context)
    {
        _context = context;
    }

    public async Task<List<StudentParent>> GetByStudentAsync(Guid studentId)
        => await _context.StudentParents.AsNoTracking()
            .Where(sp => sp.StudentId == studentId)
            .OrderBy(sp => sp.FullName)
            .ToListAsync();

    // Children that are not deleted
    public async Task<List<Guid>> GetChildIdsAsync(Guid parentAuthUserId)
        => await _context.StudentParents.AsNoTracking()
            .Where(sp => sp.ParentAuthUserId == parentAuthUserId && sp.Student.DeletedAt == null)
            .Select(sp => sp.StudentId)
            .ToListAsync();

    public async Task<StudentParent?> GetAsync(Guid studentId, Guid parentAuthUserId)
        => await _context.StudentParents
            .FirstOrDefaultAsync(sp => sp.StudentId == studentId && sp.ParentAuthUserId == parentAuthUserId);

    public async Task<bool> ExistsAsync(Guid studentId, Guid parentAuthUserId)
        => await _context.StudentParents
            .AnyAsync(sp => sp.StudentId == studentId && sp.ParentAuthUserId == parentAuthUserId && sp.Student.DeletedAt == null);

    public async Task AddAsync(StudentParent link)
    {
        await _context.StudentParents.AddAsync(link);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(StudentParent link)
    {
        _context.StudentParents.Update(link);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(StudentParent link)
    {
        _context.StudentParents.Remove(link);
        await _context.SaveChangesAsync();
    }
}
