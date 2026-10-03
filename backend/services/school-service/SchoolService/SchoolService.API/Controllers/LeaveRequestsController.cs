using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.LeaveRequests;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.API.Controllers;

// Requests to excuse a student: filed by the student or a linked parent, decided by staff.
[ApiController]
[Route("api/school/leave-requests")]
[Authorize]
public class LeaveRequestsController : ControllerBase
{
    private const string Family = Roles.Student + "," + Roles.Parent;

    private readonly ILeaveRequestService _service;
    private readonly IParentService _parents;
    private readonly ProfileAccess _access;

    public LeaveRequestsController(ILeaveRequestService service, IParentService parents, ProfileAccess access)
    {
        _service = service;
        _parents = parents;
        _access = access;
    }

    [HttpPost]
    [Authorize(Roles = Family)]
    public async Task<ActionResult<LeaveRequestResponseDto>> Create([FromBody] LeaveRequestCreateDto dto)
    {
        Guid studentId;
        if (User.IsInRole(Roles.Parent))
        {
            if (dto.StudentId is not { } childId)
                return BadRequest(new { message = "Choose which child the request is for." });
            if (!await _access.CanAccessStudentAsync(User, childId))
                return Forbid();
            studentId = childId;
        }
        else
        {
            var own = await _access.GetOwnStudentAsync(User);
            if (own == null || (dto.StudentId.HasValue && dto.StudentId != own.Id))
                return Forbid();
            studentId = own.Id;
        }

        var created = await _service.CreateAsync(studentId, User.GetAuthUserId()!.Value, dto);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    [HttpGet("mine")]
    [Authorize(Roles = Family)]
    public async Task<ActionResult> GetMine()
    {
        var studentIds = new List<Guid>();
        if (User.IsInRole(Roles.Parent))
        {
            if (User.GetAuthUserId() is { } parentId)
                studentIds.AddRange((await _parents.GetChildrenAsync(parentId)).Select(c => c.Id));
        }
        else if (await _access.GetOwnStudentAsync(User) is { } own)
        {
            studentIds.Add(own.Id);
        }
        return Ok(await _service.GetForStudentsAsync(studentIds));
    }

    [HttpGet]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult> GetAll([FromQuery] LeaveRequestStatus? status, [FromQuery] Guid? studentId)
        => Ok(await _service.GetAllAsync(status, studentId));

    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<LeaveRequestResponseDto>> Approve(Guid id, [FromBody] LeaveDecisionDto? dto)
        => Ok(await _service.DecideAsync(id, approve: true, dto?.Note));

    [HttpPost("{id:guid}/reject")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<LeaveRequestResponseDto>> Reject(Guid id, [FromBody] LeaveDecisionDto? dto)
        => Ok(await _service.DecideAsync(id, approve: false, dto?.Note));
}
