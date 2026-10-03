using System.Security.Claims;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Authorization;

public class HttpCurrentActor : ICurrentActor
{
    private readonly IHttpContextAccessor _accessor;

    public HttpCurrentActor(IHttpContextAccessor accessor) => _accessor = accessor;

    private ClaimsPrincipal? User => _accessor.HttpContext?.User;

    public Guid? AuthUserId => User?.GetAuthUserId();
    public string? Name => User?.FindFirstValue(ClaimTypes.Name);
    public string? Role => User?.FindFirstValue(ClaimTypes.Role);
}
