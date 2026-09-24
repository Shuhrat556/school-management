using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class TeacherRepository : ITeacherRepository
{
    private readonly SchoolDbContext _context;

    public TeacherRepository(SchoolDbContext context)
    {
        _context = context;
    }

    public async Task<List<Teacher>> GetAllAsync()
        => await _context.Teachers
            .AsNoTracking()
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .ToListAsync();

    public async Task<(List<Teacher> Items, int TotalCount)> GetPagedAsync(int page, int pageSize)
    {
        var query = _context.Teachers
            .AsNoTracking()
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .OrderBy(t => t.LastName)
            .ThenBy(t => t.FirstName);
        var total = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return (items, total);
    }

    public async Task<List<Teacher>> GetByDepartmentAsync(Guid departmentId)
        => await _context.Teachers
            .AsNoTracking()
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .Where(t => t.TeacherDepartments.Any(td => td.DepartmentId == departmentId))
            .OrderBy(t => t.LastName)
            .ThenBy(t => t.FirstName)
            .ToListAsync();

    public async Task<(List<Teacher> Items, int TotalCount)> GetByDepartmentPagedAsync(Guid departmentId, int page, int pageSize)
    {
        var query = _context.Teachers
            .AsNoTracking()
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .Where(t => t.TeacherDepartments.Any(td => td.DepartmentId == departmentId))
            .OrderBy(t => t.LastName)
            .ThenBy(t => t.FirstName);
        var total = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return (items, total);
    }

    public async Task<Teacher?> GetByIdAsync(Guid id)
        => await _context.Teachers
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .FirstOrDefaultAsync(t => t.Id == id);

    public async Task<Teacher?> GetByAuthUserIdAsync(Guid authUserId)
        => await _context.Teachers
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .FirstOrDefaultAsync(t => t.AuthUserId == authUserId);

    public async Task<Teacher?> GetUnlinkedByEmailAsync(string email)
    {
        var normalized = email.Trim().ToLower();
        return await _context.Teachers
            .Include(t => t.TeacherDepartments).ThenInclude(td => td.Department)
            .FirstOrDefaultAsync(t => t.AuthUserId == null && t.Email != null && t.Email.ToLower() == normalized);
    }

    public async Task AddAsync(Teacher teacher)
    {
        await _context.Teachers.AddAsync(teacher);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Teacher teacher)
    {
        _context.Teachers.Update(teacher);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Teacher teacher)
    {
        _context.Teachers.Remove(teacher);
        await _context.SaveChangesAsync();
    }
}
