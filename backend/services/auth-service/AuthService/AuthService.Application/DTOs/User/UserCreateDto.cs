using System.ComponentModel.DataAnnotations;
using AuthService.Domain.Enums;

namespace AuthService.Application.DTOs.User;

public class UserCreateDto
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    public string LastName { get; set; } = string.Empty;

    [Required]
    [StringLength(200, MinimumLength = 8)]
    public string Password { get; set; } = string.Empty;
}

public class AdminCreateUserDto
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    public string LastName { get; set; } = string.Empty;

    [Required]
    [StringLength(200, MinimumLength = 8, ErrorMessage = "Password must be 8 to 200 characters.")]
    public string Password { get; set; } = string.Empty;

    [Required]
    public UserRole Role { get; set; } = UserRole.Student;
}

public class UpdateUserRoleDto
{
    [Required]
    public UserRole Role { get; set; }
}