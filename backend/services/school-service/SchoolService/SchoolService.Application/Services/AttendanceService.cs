using SchoolService.Application.DTOs.Attendance;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class AttendanceService : IAttendanceService
{
    private readonly IAttendanceRepository _attendanceRepository;
    private readonly IClassroomRepository _classroomRepository;
    private readonly IStudentRepository _studentRepository;

    private readonly INotificationService _notifications;

    public AttendanceService(
        IAttendanceRepository attendanceRepository,
        IClassroomRepository classroomRepository,
        IStudentRepository studentRepository,
        INotificationService notifications)
    {
        _attendanceRepository = attendanceRepository;
        _classroomRepository = classroomRepository;
        _studentRepository = studentRepository;
        _notifications = notifications;
    }

    public async Task<IReadOnlyList<AttendanceResponseDto>> GetByClassroomAndDateAsync(Guid classroomId, DateOnly date)
    {
        var records = await _attendanceRepository.GetByClassroomAndDateAsync(classroomId, date);
        return records.Select(MapToResponse).ToList();
    }

    public async Task<IReadOnlyList<AttendanceResponseDto>> GetStudentHistoryAsync(Guid studentId)
    {
        var records = await _attendanceRepository.GetByStudentAsync(studentId);
        return records.Select(MapToResponse).ToList();
    }

    public async Task BulkMarkAsync(BulkMarkAttendanceDto dto)
    {
        var classroom = await _classroomRepository.GetByIdWithDetailsAsync(dto.ClassroomId);
        if (classroom == null) throw new NotFoundException("Classroom", dto.ClassroomId);

        // One mark per student and day; if a student is listed twice the last entry wins.
        var records = dto.Records.GroupBy(r => r.StudentId).Select(g => g.Last()).ToList();
        var existingMarks = new Dictionary<Guid, Attendance?>();
        foreach (var record in records)
            existingMarks[record.StudentId] = await _attendanceRepository.GetByStudentClassroomDateAsync(
                record.StudentId, dto.ClassroomId, dto.Date);

        await EnsureEnrolledAsync(classroom, records
            .Where(r => existingMarks[r.StudentId] == null)
            .Select(r => r.StudentId));

        var toAdd    = new List<Attendance>();
        var toUpdate = new List<Attendance>();
        var toNotify = new List<(Guid StudentId, AttendanceStatus Status)>();

        foreach (var record in records)
        {
            var status = (AttendanceStatus)record.Status;
            var existing = existingMarks[record.StudentId];

            // Tell the family about an absence or late arrival once, not on every re-save
            if ((status is AttendanceStatus.Absent or AttendanceStatus.Late) && existing?.Status != status)
                toNotify.Add((record.StudentId, status));

            if (existing != null)
            {
                existing.Update(dto.Date, status);
                toUpdate.Add(existing);
            }
            else
            {
                toAdd.Add(new Attendance(record.StudentId, dto.ClassroomId, dto.Date, status, dto.ScheduleId));
            }
        }

        if (toAdd.Count > 0)
            await _attendanceRepository.AddRangeAsync(toAdd);

        foreach (var a in toUpdate)
            await _attendanceRepository.UpdateAsync(a);

        foreach (var (studentId, status) in toNotify)
            await _notifications.NotifyStudentAsync(studentId, NotificationType.Attendance,
                status == AttendanceStatus.Absent ? "Marked absent" : "Marked late",
                $"{classroom.Name} on {dto.Date:yyyy-MM-dd}.");
    }

    // A new mark needs a current enrolment; an existing one may still be corrected after the student left.
    private async Task EnsureEnrolledAsync(Classroom classroom, IEnumerable<Guid> studentIds)
    {
        var roster = classroom.StudentClassrooms
            .Where(sc => sc.Status == StudentClassroomStatus.Active && sc.Student?.DeletedAt == null)
            .Select(sc => sc.StudentId)
            .ToHashSet();
        var outsiders = studentIds.Where(id => !roster.Contains(id)).ToList();
        if (outsiders.Count == 0) return;

        var names = new List<string>();
        foreach (var id in outsiders)
        {
            var student = await _studentRepository.GetByIdAsync(id);
            names.Add(student != null ? $"{student.FirstName} {student.LastName}" : $"unknown student {id}");
        }
        throw new ValidationException($"Not enrolled in {classroom.Name}: {string.Join(", ", names)}.");
    }

    private static AttendanceResponseDto MapToResponse(Attendance a) => new()
    {
        Id            = a.Id,
        StudentId     = a.StudentId,
        StudentName   = a.Student != null ? $"{a.Student.FirstName} {a.Student.LastName}" : "",
        ClassroomId   = a.ClassroomId,
        ClassroomName = a.Classroom?.Name,
        ScheduleId    = a.ScheduleId,
        Date          = a.Date,
        Status        = a.Status.ToString(),
        CreatedAt     = a.CreatedAt
    };
}
