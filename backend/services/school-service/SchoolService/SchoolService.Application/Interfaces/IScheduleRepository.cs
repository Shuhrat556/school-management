using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface IScheduleRepository
{
    Task<List<Schedule>> GetByClassroomAsync(Guid classroomId);
    Task<List<Schedule>> GetByTeacherAsync(Guid teacherId);
    Task<Schedule?> GetByIdAsync(Guid id);
    Task AddAsync(Schedule schedule);
    Task UpdateAsync(Schedule schedule);
    Task DeleteAsync(Schedule schedule);
    /// <summary>
    /// Returns active schedules (with their classroom) that overlap the requested day+time window.
    /// Used for teacher, classroom and room conflict detection before creating/updating a schedule.
    /// </summary>
    Task<List<Schedule>> GetOverlappingAsync(SchoolDayOfWeek day, TimeOnly start, TimeOnly end, Guid? excludeScheduleId = null);
}
