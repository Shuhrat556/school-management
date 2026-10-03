using System.ComponentModel.DataAnnotations;

namespace SchoolService.Application.DTOs.LeaveRequests;

public class LeaveRequestCreateDto
{
    /// <summary>Required when a parent asks for a child; a student always asks for themselves.</summary>
    public Guid? StudentId { get; set; }

    /// <summary>1=Sick, 2=Personal, 3=Other</summary>
    [Range(1, 3)]
    public int Type { get; set; } = 1;

    [Required]
    public DateOnly StartDate { get; set; }

    /// <summary>Defaults to StartDate (a single day).</summary>
    public DateOnly? EndDate { get; set; }

    [Required]
    [StringLength(1000, MinimumLength = 1)]
    public string Reason { get; set; } = null!;
}

public class LeaveDecisionDto
{
    [StringLength(500)]
    public string? Note { get; set; }
}

public class LeaveRequestResponseDto
{
    public Guid Id { get; set; }
    public Guid StudentId { get; set; }
    public string StudentName { get; set; } = null!;
    /// <summary>"Sick", "Personal" or "Other".</summary>
    public string Type { get; set; } = null!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string Reason { get; set; } = null!;
    /// <summary>"Pending", "Approved" or "Rejected".</summary>
    public string Status { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
    public string? ReviewedByName { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public string? ReviewNote { get; set; }
}
