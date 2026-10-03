using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class ScheduleRepository : IScheduleRepository
{
    private readonly SchoolDbContext _context;

    public ScheduleRepository(SchoolDbContext context) => _context = context;

    public async Task<List<Schedule>> GetByClassroomAsync(Guid classroomId)
        => await _context.Schedules
            .AsNoTracking()
            .Include(s => s.Subject)
            .Include(s => s.Teacher)
            .Include(s => s.Classroom)
            .Where(s => s.ClassroomId == classroomId && s.DeletedAt == null)
            .OrderBy(s => s.DayOfWeek).ThenBy(s => s.StartTime)
            .ToListAsync();

    public async Task<List<Schedule>> GetByTeacherAsync(Guid teacherId)
        => await _context.Schedules
            .AsNoTracking()
            .Include(s => s.Subject)
            .Include(s => s.Classroom)
            .Where(s => s.TeacherId == teacherId && s.DeletedAt == null)
            .OrderBy(s => s.DayOfWeek).ThenBy(s => s.StartTime)
            .ToListAsync();

    public async Task<Schedule?> GetByIdAsync(Guid id)
        => await _context.Schedules
            .Include(s => s.Subject)
            .Include(s => s.Teacher)
            .Include(s => s.Classroom)
            .FirstOrDefaultAsync(s => s.Id == id);

    public async Task<List<Schedule>> GetOverlappingAsync(
        SchoolDayOfWeek day, TimeOnly start, TimeOnly end,
        Guid? excludeScheduleId = null)
        => await _context.Schedules
            .AsNoTracking()
            .Include(s => s.Classroom)
            .Where(s =>
                s.DayOfWeek == day &&
                s.DeletedAt == null &&
                s.StartTime < end &&
                s.EndTime > start &&
                (excludeScheduleId == null || s.Id != excludeScheduleId))
            .ToListAsync();

    public async Task AddAsync(Schedule schedule)
    {
        await _context.Schedules.AddAsync(schedule);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Schedule schedule)
    {
        _context.Schedules.Update(schedule);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Schedule schedule)
    {
        _context.Schedules.Remove(schedule);
        await _context.SaveChangesAsync();
    }
}
