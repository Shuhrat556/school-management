using System.ComponentModel.DataAnnotations;

namespace SchoolService.Application.DTOs.Submissions;

public class SubmissionCreateDto
{
    [Required]
    public Guid MaterialId { get; set; }

    [StringLength(1000)]
    [SafeLink]
    public string? SubmissionUrl { get; set; }
}

public class GradeSubmissionDto
{
    [Range(0, 100)]
    public decimal? Grade { get; set; }

    [StringLength(1000)]
    public string? Feedback { get; set; }
}

public class SubmissionResponseDto
{
    public Guid Id { get; set; }
    public Guid MaterialId { get; set; }
    public string MaterialTitle { get; set; } = null!;
    public Guid StudentId { get; set; }
    public string StudentName { get; set; } = null!;
    public string? SubmissionUrl { get; set; }
    public DateTime SubmittedAt { get; set; }
    public decimal? Grade { get; set; }
    public string? Feedback { get; set; }
}
