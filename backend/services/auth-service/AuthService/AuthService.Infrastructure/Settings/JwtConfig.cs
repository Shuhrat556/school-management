using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace AuthService.Infrastructure.Settings;

// Single place that decides which key signs tokens and how they are validated,
// so issuing (TokenService), [Authorize] and /api/auth/validate always agree.
public static class JwtConfig
{
    public static string ResolveSecret(IConfiguration configuration)
    {
        return (!string.IsNullOrEmpty(configuration["Jwt:Secret"]) ? configuration["Jwt:Secret"] : null)
            ?? (!string.IsNullOrEmpty(configuration["Jwt__Secret"]) ? configuration["Jwt__Secret"] : null)
            ?? (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("JWT_SECRET")) ? Environment.GetEnvironmentVariable("JWT_SECRET") : null)
            ?? "your-secret-key-change-me-in-production-this-is-insecure";
    }

    public static SymmetricSecurityKey GetSigningKey(IConfiguration configuration)
        => new(Encoding.UTF8.GetBytes(ResolveSecret(configuration)));

    public static TokenValidationParameters CreateValidationParameters(IConfiguration configuration)
    {
        return new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = GetSigningKey(configuration),
            ValidateIssuer = true,
            ValidIssuer = configuration["Jwt:Issuer"],
            ValidateAudience = true,
            ValidAudience = configuration["Jwt:Audience"],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    }
}
