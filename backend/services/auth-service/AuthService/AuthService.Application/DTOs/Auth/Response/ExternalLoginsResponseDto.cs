namespace AuthService.Application.DTOs.Auth.Response;

public class ExternalLoginsResponseDto
{
    public bool HasPassword { get; set; }
    public List<ExternalLoginDto> Logins { get; set; } = new();
}

public class ExternalLoginDto
{
    /// <summary>"Google" or "Facebook".</summary>
    public string Provider { get; set; } = string.Empty;
    public DateTime LinkedAt { get; set; }
}
