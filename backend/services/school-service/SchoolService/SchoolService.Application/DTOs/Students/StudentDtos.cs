using System.ComponentModel.DataAnnotations;

namespace SchoolService.Application.DTOs.Students;

public class StudentCreateDto
{
    [Required(ErrorMessage = "FirstName is required.")]
    [StringLength(100, ErrorMessage = "FirstName cannot exceed 100 characters.")]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "LastName is required.")]
    [StringLength(100, ErrorMessage = "LastName cannot exceed 100 characters.")]
    public string LastName { get; set; } = null!;

    [StringLength(10)]
    public string? Gender { get; set; }

    public DateTime? DateOfBirth { get; set; }

    [StringLength(20)]
    public string? Phone { get; set; }

    [StringLength(255)]
    public string? Address { get; set; }

    [StringLength(200)]
    [EmailAddress]
    public string? Email { get; set; }

    public bool IsActive { get; set; } = true;
}

public class StudentUpdateDto
{
    [Required(ErrorMessage = "FirstName is required.")]
    [StringLength(100, ErrorMessage = "FirstName cannot exceed 100 characters.")]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "LastName is required.")]
    [StringLength(100, ErrorMessage = "LastName cannot exceed 100 characters.")]
    public string LastName { get; set; } = null!;

    [StringLength(10)]
    public string? Gender { get; set; }

    public DateTime? DateOfBirth { get; set; }

    [StringLength(20)]
    public string? Phone { get; set; }

    [StringLength(255)]
    public string? Address { get; set; }

    [StringLength(200)]
    [EmailAddress]
    public string? Email { get; set; }

    public bool IsActive { get; set; } = true;
}

public class StudentResponseDto
{
    public Guid Id { get; set; }
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string? Gender { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

