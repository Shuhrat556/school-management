using System.ComponentModel.DataAnnotations;

namespace SchoolService.Application.DTOs.Parents;

public class StudentParentCreateDto
{
    // The parent's login account in auth-service (role Parent)
    [Required]
    public Guid ParentAuthUserId { get; set; }

    [Required(ErrorMessage = "FullName is required.")]
    [StringLength(200)]
    public string FullName { get; set; } = null!;

    [StringLength(200)]
    [EmailAddress]
    public string? Email { get; set; }

    [StringLength(50)]
    public string? Relationship { get; set; }
}

public class StudentParentResponseDto
{
    public Guid Id { get; set; }
    public Guid StudentId { get; set; }
    public Guid ParentAuthUserId { get; set; }
    public string FullName { get; set; } = null!;
    public string? Email { get; set; }
    public string? Relationship { get; set; }
    public DateTime CreatedAt { get; set; }
}
