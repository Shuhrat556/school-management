namespace SchoolService.Application.DTOs.ReportCards;

public class ReportCardDto
{
    public Guid StudentId { get; set; }
    public string StudentName { get; set; } = null!;
    /// <summary>Null when the card covers every semester.</summary>
    public string? Semester { get; set; }
    /// <summary>Attendance window; null bounds are open.</summary>
    public DateOnly? From { get; set; }
    public DateOnly? To { get; set; }
    public DateTime GeneratedAt { get; set; }
    public List<ReportCardSubjectDto> Subjects { get; set; } = new();
    /// <summary>Mean score 0–100; null without grades.</summary>
    public decimal? AverageScore { get; set; }
    /// <summary>Mean grade points on a 4.0 scale; null without grades.</summary>
    public decimal? Gpa { get; set; }
    public ReportCardAttendanceDto Attendance { get; set; } = new();
}

public class ReportCardSubjectDto
{
    public Guid SubjectId { get; set; }
    public string SubjectName { get; set; } = null!;
    public string Semester { get; set; } = null!;
    public string? ClassroomName { get; set; }
    public decimal Score { get; set; }
    public string Letter { get; set; } = null!;
    public decimal GradePoints { get; set; }
}

public class ReportCardAttendanceDto
{
    public int Total { get; set; }
    public int Present { get; set; }
    public int Absent { get; set; }
    public int Late { get; set; }
    /// <summary>Present marks as a percentage of all marks (late is not present); null without marks.</summary>
    public decimal? Rate { get; set; }
}
