using System.ComponentModel.DataAnnotations;

namespace AuthService.Application.DTOs.Auth.Request;

public class LoginRequestDto
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    // Long inputs only cost hashing time; no real password is longer
    [Required]
    [StringLength(200)]
    public string Password { get; set; } = string.Empty;
}
