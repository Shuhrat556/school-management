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

    // Deleted students keep their row (and grades, attendance, submissions) but are never returned.
    private IQueryable<Student> Active => _context.Students.Where(s => s.DeletedAt == null);

    public async Task<List<Student>> GetAllAsync()
        => await Active.AsNoTracking().ToListAsync();

    public async Task<(List<Student> Items, int TotalCount)> GetPagedAsync(int page, int pageSize)
    {
        var query = Active.AsNoTracking().OrderBy(s => s.LastName).ThenBy(s => s.FirstName);
        var total = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
        return (items, total);
    }

    public async Task<Student?> GetByIdAsync(Guid id)
        => await Active.FirstOrDefaultAsync(s => s.Id == id);

    public async Task<Student?> GetByAuthUserIdAsync(Guid authUserId)
        => await Active.FirstOrDefaultAsync(s => s.AuthUserId == authUserId);

    public async Task<Student?> GetUnlinkedByEmailAsync(string email)
    {
        var normalized = email.Trim().ToLower();
        return await Active
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
        student.SoftDelete();
        student.Deactivate();
        _context.Students.Update(student);

        // A deleted student leaves every class they are still in.
        var enrollments = await _context.StudentClassrooms
            .Where(sc => sc.StudentId == student.Id && sc.Status == StudentClassroomStatus.Active)
            .ToListAsync();
        foreach (var enrollment in enrollments)
            enrollment.Drop();

        await _context.SaveChangesAsync();
    }
}

