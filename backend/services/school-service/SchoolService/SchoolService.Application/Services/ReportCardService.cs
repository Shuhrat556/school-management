using SchoolService.Application.DTOs.ReportCards;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class ReportCardService : IReportCardService
{
    private readonly IStudentRepository _students;
    private readonly IGradeRepository _grades;
    private readonly IAttendanceRepository _attendance;

    public ReportCardService(IStudentRepository students, IGradeRepository grades, IAttendanceRepository attendance)
    {
        _students = students;
        _grades = grades;
        _attendance = attendance;
    }

    public async Task<ReportCardDto> GetAsync(Guid studentId, string? semester, DateOnly? from, DateOnly? to)
    {
        if (from > to) throw new ValidationException("'from' must not be after 'to'.");

        var student = await _students.GetByIdAsync(studentId);
        if (student == null) throw new NotFoundException("Student", studentId);

        semester = string.IsNullOrWhiteSpace(semester) ? null : semester.Trim();
        var subjects = (await _grades.GetFilteredAsync(studentId, null, semester))
            .Select(g => new ReportCardSubjectDto
            {
                SubjectId     = g.SubjectId,
                SubjectName   = g.Subject?.SubjectName ?? "",
                Semester      = g.Semester,
                ClassroomName = g.Classroom?.Name,
                Score         = g.Score,
                Letter        = GradeScale.Letter(g.Score),
                GradePoints   = GradeScale.Points(g.Score)
            })
            .OrderBy(s => s.Semester, StringComparer.Ordinal)
            .ThenBy(s => s.SubjectName, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var marks = (await _attendance.GetByStudentAsync(studentId))
            .Where(a => (from == null || a.Date >= from) && (to == null || a.Date <= to))
            .ToList();
        var present = marks.Count(a => a.Status == AttendanceStatus.Present);

        return new ReportCardDto
        {
            StudentId    = student.Id,
            StudentName  = $"{student.FirstName} {student.LastName}",
            Semester     = semester,
            From         = from,
            To           = to,
            GeneratedAt  = DateTime.UtcNow,
            Subjects     = subjects,
            AverageScore = subjects.Count == 0 ? null : Round(subjects.Average(s => s.Score), 2),
            Gpa          = subjects.Count == 0 ? null : Round(subjects.Average(s => s.GradePoints), 2),
            Attendance   = new ReportCardAttendanceDto
            {
                Total   = marks.Count,
                Present = present,
                Absent  = marks.Count(a => a.Status == AttendanceStatus.Absent),
                Late    = marks.Count(a => a.Status == AttendanceStatus.Late),
                Rate    = marks.Count == 0 ? null : Round(present * 100m / marks.Count, 1)
            }
        };
    }

    private static decimal Round(decimal value, int decimals) => Math.Round(value, decimals, MidpointRounding.AwayFromZero);
}
