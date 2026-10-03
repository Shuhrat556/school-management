namespace SchoolService.Application.DTOs.Grades;

public class GradeChangeResponseDto
{
    public Guid Id { get; set; }
    public Guid GradeId { get; set; }
    public Guid StudentId { get; set; }
    public string? StudentName { get; set; }
    public Guid SubjectId { get; set; }
    public string? SubjectName { get; set; }
    public string Semester { get; set; } = null!;
    /// <summary>Created, Updated or Deleted.</summary>
    public string Action { get; set; } = null!;
    public decimal? OldScore { get; set; }
    public decimal? NewScore { get; set; }
    public Guid? ChangedByAuthUserId { get; set; }
    public string? ChangedByName { get; set; }
    public string? ChangedByRole { get; set; }
    public DateTime ChangedAt { get; set; }
}
