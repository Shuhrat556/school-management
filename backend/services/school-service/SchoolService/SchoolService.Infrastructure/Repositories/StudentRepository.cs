using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class StudentRepository : IStudentRepository
{
    private readonly SchoolDbContext _context;

    public StudentRepository(SchoolDbContext context)
    {
        _context = context;
    }

    public async Task<List<Student>> GetAllAsync()
        => await _context.Students.AsNoTracking().ToListAsync();

    public async Task<(List<Student> Items, int TotalCount)> GetPagedAsync(int page, int pageSize)
    {
        var query = _context.Students.AsNoTracking().OrderBy(s => s.LastName).ThenBy(s => s.FirstName);
        var total = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return (items, total);
    }

    public async Task<Student?> GetByIdAsync(Guid id)
        => await _context.Students.FindAsync(id);

    public async Task<Student?> GetByAuthUserIdAsync(Guid authUserId)
        => await _context.Students.FirstOrDefaultAsync(s => s.AuthUserId == authUserId);

    public async Task<Student?> GetUnlinkedByEmailAsync(string email)
    {
        var normalized = email.Trim().ToLower();
        return await _context.Students
            .FirstOrDefaultAsync(s => s.AuthUserId == null && s.Email != null && s.Email.ToLower() == normalized);
    }

    public async Task AddAsync(Student student)
    {
        await _context.Students.AddAsync(student);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Student student)
    {
        _context.Students.Update(student);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Student student)
    {
        _context.Students.Remove(student);
        await _context.SaveChangesAsync();
    }
}

