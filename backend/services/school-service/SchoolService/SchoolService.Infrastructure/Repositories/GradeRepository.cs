using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class GradeRepository : IGradeRepository
{
    private readonly SchoolDbContext _context;

    public GradeRepository(SchoolDbContext context) => _context = context;

    public async Task<List<StudentGrade>> GetFilteredAsync(Guid? studentId, Guid? subjectId, string? semester)
    {
        var query = _context.StudentGrades
            .AsNoTracking()
            .Include(g => g.Student)
            .Include(g => g.Subject)
            .Include(g => g.Classroom)
            .AsQueryable();

        if (studentId.HasValue)  query = query.Where(g => g.StudentId == studentId.Value);
        if (subjectId.HasValue)  query = query.Where(g => g.SubjectId == subjectId.Value);
        if (!string.IsNullOrWhiteSpace(semester)) query = query.Where(g => g.Semester == semester);

        return await query.OrderBy(g => g.Semester).ToListAsync();
    }

    public async Task<StudentGrade?> GetByIdAsync(Guid id)
        => await _context.StudentGrades
            .Include(g => g.Student)
            .Include(g => g.Subject)
            .Include(g => g.Classroom)
            .FirstOrDefaultAsync(g => g.Id == id);

    public async Task<StudentGrade?> GetByStudentSubjectSemesterAsync(Guid studentId, Guid subjectId, string semester)
        => await _context.StudentGrades
            .FirstOrDefaultAsync(g => g.StudentId == studentId && g.SubjectId == subjectId && g.Semester == semester);

    public async Task AddAsync(StudentGrade grade)
    {
        await _context.StudentGrades.AddAsync(grade);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(StudentGrade grade)
    {
        _context.StudentGrades.Update(grade);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(StudentGrade grade)
    {
        _context.StudentGrades.Remove(grade);
        await _context.SaveChangesAsync();
    }
}
