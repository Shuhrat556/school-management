using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/parents")]
[Authorize(Roles = Roles.Parent)]
public class ParentsController : ControllerBase
{
    private readonly IParentService _parentService;

    public ParentsController(IParentService parentService) => _parentService = parentService;

    // The signed-in parent's children; their grades, attendance and submissions
    // are then read through the regular student endpoints.
    [HttpGet("me/children")]
    public async Task<ActionResult> GetMyChildren()
    {
        var parentId = User.GetAuthUserId();
        if (parentId == null)
            return Forbid();

        return Ok(await _parentService.GetChildrenAsync(parentId.Value));
    }
}
