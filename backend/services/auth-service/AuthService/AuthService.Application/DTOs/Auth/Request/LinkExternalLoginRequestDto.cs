using System.ComponentModel.DataAnnotations;

namespace AuthService.Application.DTOs.Auth.Request;

public class LinkExternalLoginRequestDto
{
    /// <summary>Google ID token or Facebook access token of the account to link.</summary>
    [Required]
    public string Token { get; set; } = string.Empty;
}
