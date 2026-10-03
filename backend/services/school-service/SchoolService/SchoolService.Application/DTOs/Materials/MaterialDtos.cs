using System.ComponentModel.DataAnnotations;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.DTOs.Materials;

public class MaterialCreateDto
{
    [Required]
    public Guid ClassroomId { get; set; }

    [Required]
    [StringLength(200)]
    public string Title { get; set; } = null!;

    [StringLength(500)]
    public string? Description { get; set; }

    [StringLength(1000)]
    [SafeLink]
    public string? Url { get; set; }

    public MaterialType Type { get; set; }

    /// <summary>Optional deadline for an assignment (UTC).</summary>
    public DateTime? DueAt { get; set; }
}

public class MaterialUpdateDto
{
    [Required]
    [StringLength(200)]
    public string Title { get; set; } = null!;

    [StringLength(500)]
    public string? Description { get; set; }

    [StringLength(1000)]
    [SafeLink]
    public string? Url { get; set; }

    public MaterialType Type { get; set; }

    public DateTime? DueAt { get; set; }

    public bool IsActive { get; set; }
}

public class MaterialResponseDto
{
    public Guid Id { get; set; }
    public Guid ClassroomId { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public string? Url { get; set; }
    public MaterialType Type { get; set; }
    public DateTime? DueAt { get; set; }
    /// <summary>Students who handed in work (each counted once).</summary>
    public int SubmissionCount { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
