using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Announcements;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/announcements")]
[Authorize]
public class AnnouncementsController : ControllerBase
{
    private readonly IAnnouncementService _service;
    private readonly ProfileAccess _access;

    public AnnouncementsController(IAnnouncementService service, ProfileAccess access)
    {
        _service = service;
        _access = access;
    }

    // Admins manage every announcement; a teacher only their own.
    private async Task<bool> CanManageAsync(Guid id)
    {
        if (User.IsInRole(Roles.Admin))
            return true;

        var own = await _access.GetOwnTeacherAsync(User);
        return own != null && (await _service.GetByIdAsync(id)).AuthorTeacherId == own.Id;
    }

    /// <summary>Get all announcements. Pass classroomId to get school-wide + classroom-specific.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] Guid? classroomId)
    {
        var result = await _service.GetAllAsync(classroomId);
        // Drafts are for staff only
        return Ok(User.IsStaff() ? result : result.Where(a => a.IsPublished).ToList());
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await _service.GetByIdAsync(id);
        if (!result.IsPublished && !User.IsStaff())
            return NotFound();
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Create([FromBody] AnnouncementCreateDto dto)
    {
        // A teacher always posts as themselves; an admin names the author.
        if (!User.IsInRole(Roles.Admin))
        {
            var own = await _access.GetOwnTeacherAsync(User);
            if (own == null)
                return Forbid();
            dto.AuthorTeacherId = own.Id;
        }

        var result = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Update(Guid id, [FromBody] AnnouncementUpdateDto dto)
    {
        if (!await CanManageAsync(id))
            return Forbid();

        var result = await _service.UpdateAsync(id, dto);
        return Ok(result);
    }

    [HttpPost("{id:guid}/publish")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Publish(Guid id)
    {
        if (!await CanManageAsync(id))
            return Forbid();

        var result = await _service.PublishAsync(id);
        return Ok(result);
    }

    [HttpPost("{id:guid}/unpublish")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Unpublish(Guid id)
    {
        if (!await CanManageAsync(id))
            return Forbid();

        var result = await _service.UnpublishAsync(id);
        return Ok(result);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Delete(Guid id)
    {
        if (!await CanManageAsync(id))
            return Forbid();

        await _service.DeleteAsync(id);
        return NoContent();
    }
}
