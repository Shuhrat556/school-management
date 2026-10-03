using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class TeachingRepository : ITeachingRepository
{
    private readonly SchoolDbContext _context;

    public TeachingRepository(SchoolDbContext context) => _context = context;

    private IQueryable<Guid> ClassIdsTaughtBy(Guid teacherId)
        => _context.Classrooms.Where(c => c.TeacherId == teacherId).Select(c => c.Id)
            .Union(_context.Schedules.Where(s => s.TeacherId == teacherId && s.DeletedAt == null).Select(s => s.ClassroomId));

    public async Task<bool> TeachesClassroomAsync(Guid teacherId, Guid classroomId)
        => await ClassIdsTaughtBy(teacherId).AnyAsync(id => id == classroomId);

    public async Task<bool> TeachesStudentAsync(Guid teacherId, Guid studentId)
    {
        var classIds = ClassIdsTaughtBy(teacherId);
        return await _context.StudentClassrooms.AnyAsync(sc =>
            sc.StudentId == studentId && sc.Status == StudentClassroomStatus.Active && classIds.Contains(sc.ClassroomId));
    }
}
