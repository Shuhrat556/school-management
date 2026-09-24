using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace SchoolService.API.Authorization;

public static class ClaimsPrincipalExtensions
{
    // The auth-service user id ("sub"); JwtBearer maps it to NameIdentifier by default.
    public static Guid? GetAuthUserId(this ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Guid.TryParse(value, out var id) ? id : null;
    }

    public static bool IsStaff(this ClaimsPrincipal user)
        => user.IsInRole(Roles.Admin) || user.IsInRole(Roles.Teacher);
}
