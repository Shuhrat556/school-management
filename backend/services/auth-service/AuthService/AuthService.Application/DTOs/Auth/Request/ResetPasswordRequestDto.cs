using System.ComponentModel.DataAnnotations;

namespace AuthService.Application.DTOs.Auth.Request;

public class ResetPasswordRequestDto
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [RegularExpression(@"^\d{6}$")]
    public string Code { get; set; } = string.Empty;

    [Required]
    [StringLength(200, MinimumLength = 8)]
    public string NewPassword { get; set; } = string.Empty;
}
