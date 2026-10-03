using SchoolService.Application.DTOs.Schedules;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class ScheduleService : IScheduleService
{
    private readonly IScheduleRepository _scheduleRepository;
    private readonly IClassroomRepository _classroomRepository;
    private readonly ISubjectRepository _subjectRepository;
    private readonly ITeacherRepository _teacherRepository;
    private readonly IRoomRepository _roomRepository;

    public ScheduleService(
        IScheduleRepository scheduleRepository,
        IClassroomRepository classroomRepository,
        ISubjectRepository subjectRepository,
        ITeacherRepository teacherRepository,
        IRoomRepository roomRepository)
    {
        _scheduleRepository = scheduleRepository;
        _classroomRepository = classroomRepository;
        _subjectRepository = subjectRepository;
        _teacherRepository = teacherRepository;
        _roomRepository = roomRepository;
    }

    public async Task<IReadOnlyList<ScheduleResponseDto>> GetByClassroomAsync(Guid classroomId)
    {
        var schedules = await _scheduleRepository.GetByClassroomAsync(classroomId);
        return schedules.Select(MapToResponse).ToList();
    }

    public async Task<IReadOnlyList<ScheduleResponseDto>> GetByTeacherAsync(Guid teacherId)
    {
        var schedules = await _scheduleRepository.GetByTeacherAsync(teacherId);
        return schedules.Select(MapToResponse).ToList();
    }

    public async Task<ScheduleResponseDto> GetByIdAsync(Guid id)
    {
        var schedule = await _scheduleRepository.GetByIdAsync(id);
        if (schedule == null) throw new NotFoundException("Schedule", id);
        return MapToResponse(schedule);
    }

    public async Task<ScheduleResponseDto> CreateAsync(ScheduleCreateDto dto)
    {
        var classroom = await _classroomRepository.GetByIdAsync(dto.ClassroomId);
        if (classroom == null) throw new NotFoundException("Classroom", dto.ClassroomId);

        var subject = await _subjectRepository.GetByIdAsync(dto.SubjectId);
        if (subject == null) throw new NotFoundException("Subject", dto.SubjectId);

        var day   = (SchoolDayOfWeek)dto.DayOfWeek;
        var start = dto.StartTime;
        var end   = dto.EndTime;

        await EnsureNoConflictAsync(classroom, dto.TeacherId, day, start, end);

        var schedule = new Schedule(dto.ClassroomId, dto.SubjectId, dto.TeacherId,
            day, start, end, (SessionType)dto.Type);
        await _scheduleRepository.AddAsync(schedule);

        var loaded = await _scheduleRepository.GetByIdAsync(schedule.Id);
        return loaded != null ? MapToResponse(loaded) : MapToResponse(schedule);
    }

    public async Task<ScheduleResponseDto> UpdateAsync(Guid id, ScheduleUpdateDto dto)
    {
        var schedule = await _scheduleRepository.GetByIdAsync(id);
        if (schedule == null) throw new NotFoundException("Schedule", id);

        var day   = (SchoolDayOfWeek)dto.DayOfWeek;
        var start = dto.StartTime;
        var end   = dto.EndTime;

        var classroom = await _classroomRepository.GetByIdAsync(schedule.ClassroomId);
        if (classroom == null) throw new NotFoundException("Classroom", schedule.ClassroomId);

        await EnsureNoConflictAsync(classroom, dto.TeacherId, day, start, end, excludeScheduleId: id);

        schedule.UpdateInfo(day, start, end, (SessionType)dto.Type);
        schedule.UpdateTeacher(dto.TeacherId);
        await _scheduleRepository.UpdateAsync(schedule);
        return MapToResponse(schedule);
    }

    public async Task DeleteAsync(Guid id)
    {
        var schedule = await _scheduleRepository.GetByIdAsync(id);
        if (schedule == null) throw new NotFoundException("Schedule", id);
        await _scheduleRepository.DeleteAsync(schedule);
    }

    // A teacher, a class and a room (except shared spaces such as a gym or auditorium) can be in one place at a time.
    private async Task EnsureNoConflictAsync(Classroom classroom, Guid? teacherId,
        SchoolDayOfWeek day, TimeOnly start, TimeOnly end, Guid? excludeScheduleId = null)
    {
        if (end <= start)
            throw new ValidationException("EndTime must be after StartTime.");

        if (teacherId.HasValue && await _teacherRepository.GetByIdAsync(teacherId.Value) == null)
            throw new NotFoundException("Teacher", teacherId.Value);

        var overlapping = await _scheduleRepository.GetOverlappingAsync(day, start, end, excludeScheduleId);

        if (teacherId.HasValue && overlapping.Any(s => s.TeacherId == teacherId))
            throw new ConflictException($"Teacher already has a schedule on {day} from {start} to {end}.");

        if (overlapping.Any(s => s.ClassroomId == classroom.Id))
            throw new ConflictException($"Classroom '{classroom.Name}' already has a session on {day} between {start} and {end}.");

        if (classroom.RoomId is not { } roomId || !overlapping.Any(s => s.Classroom?.RoomId == roomId))
            return;
        var room = await _roomRepository.GetByIdAsync(roomId);
        if (room?.Type is RoomType.Classroom or RoomType.Lab)
            throw new ConflictException($"Room '{room.Name}' is already booked on {day} between {start} and {end}.");
    }

    private static ScheduleResponseDto MapToResponse(Schedule s) => new()
    {
        Id            = s.Id,
        ClassroomId   = s.ClassroomId,
        ClassroomName = s.Classroom?.Name ?? "",
        SubjectId     = s.SubjectId,
        SubjectName   = s.Subject?.SubjectName ?? "",
        TeacherId     = s.TeacherId,
        TeacherName   = s.Teacher != null ? $"{s.Teacher.FirstName} {s.Teacher.LastName}" : null,
        DayOfWeek     = (int)s.DayOfWeek,
        DayOfWeekName = s.DayOfWeek.ToString(),
        StartTime     = s.StartTime,
        EndTime       = s.EndTime,
        Type          = (int)s.Type,
        TypeName      = s.Type.ToString()
    };
}
