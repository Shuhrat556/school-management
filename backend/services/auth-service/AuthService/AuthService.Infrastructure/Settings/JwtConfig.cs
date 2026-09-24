using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace AuthService.Infrastructure.Settings;

// Single place that decides which key signs tokens and how they are validated,
// so issuing (TokenService), [Authorize] and /api/auth/validate always agree.
public static class JwtConfig
{
    // HS256 needs a key of at least 256 bits.
    public const int MinimumSecretBytes = 32;

    // Published in the repository, so it is only acceptable for local development.
    private const string DevelopmentFallbackSecret = "your-secret-key-change-me-in-production-this-is-insecure";

    public static string ResolveSecret(IConfiguration configuration)
    {
        return (!string.IsNullOrEmpty(configuration["Jwt:Secret"]) ? configuration["Jwt:Secret"] : null)
            ?? (!string.IsNullOrEmpty(configuration["Jwt__Secret"]) ? configuration["Jwt__Secret"] : null)
            ?? (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("JWT_SECRET")) ? Environment.GetEnvironmentVariable("JWT_SECRET") : null)
            ?? DevelopmentFallbackSecret;
    }

    // Outside Development, refuse to start with the public fallback key or a short one:
    // anyone could otherwise forge tokens with any role.
    public static void EnsureUsableSecret(IConfiguration configuration, bool isDevelopment)
    {
        if (isDevelopment)
            return;

        var secret = ResolveSecret(configuration);
        if (secret == DevelopmentFallbackSecret || Encoding.UTF8.GetByteCount(secret) < MinimumSecretBytes)
            throw new InvalidOperationException(
                $"Jwt:Secret (JWT_SECRET) must be a random value of at least {MinimumSecretBytes} bytes outside Development.");
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
