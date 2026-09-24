using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace SchoolService.Tests.Infrastructure;

// Issues tokens shaped like auth-service's (sub, email, role) signed with the test key.
public static class TestTokens
{
    public const string Secret = "test-only-signing-key-0123456789abcdef0123456789";
    public const string Issuer = "AuthService";
    public const string Audience = "AuthServiceClients";

    public static string Create(string role, Guid authUserId, string? email = null)
    {
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, authUserId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, email ?? $"{authUserId:N}@test.local"),
            new Claim(ClaimTypes.Name, "Test User"),
            new Claim(ClaimTypes.Role, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret)), SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(Issuer, Audience, claims,
            expires: DateTime.UtcNow.AddMinutes(10), signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public static HttpClient WithToken(this HttpClient client, string token)
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}
