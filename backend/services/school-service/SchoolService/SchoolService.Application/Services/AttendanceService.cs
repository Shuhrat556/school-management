using SchoolService.Application.DTOs.Attendance;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class AttendanceService : IAttendanceService
{
    private readonly IAttendanceRepository _attendanceRepository;
    private readonly IClassroomRepository _classroomRepository;

    public AttendanceService(
        IAttendanceRepository attendanceRepository,
        IClassroomRepository classroomRepository)
    {
        _attendanceRepository = attendanceRepository;
        _classroomRepository = classroomRepository;
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
        var classroom = await _classroomRepository.GetByIdAsync(dto.ClassroomId);
        if (classroom == null) throw new NotFoundException("Classroom", dto.ClassroomId);

        var toAdd    = new List<Attendance>();
        var toUpdate = new List<Attendance>();

        // One mark per student and day; if a student is listed twice the last entry wins.
        foreach (var record in dto.Records.GroupBy(r => r.StudentId).Select(g => g.Last()))
        {
            var status = (AttendanceStatus)record.Status;
            var existing = await _attendanceRepository.GetByStudentClassroomDateAsync(
                record.StudentId, dto.ClassroomId, dto.Date);

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
