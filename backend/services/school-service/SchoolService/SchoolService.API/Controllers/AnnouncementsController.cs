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

    public AnnouncementsController(IAnnouncementService service)
    {
        _service = service;
    }

    /// <summary>Get all announcements. Pass classroomId to get school-wide + classroom-specific.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] Guid? classroomId)
    {
        var result = await _service.GetAllAsync(classroomId);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var result = await _service.GetByIdAsync(id);
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Create([FromBody] AnnouncementCreateDto dto)
    {
        var result = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Update(Guid id, [FromBody] AnnouncementUpdateDto dto)
    {
        var result = await _service.UpdateAsync(id, dto);
        return Ok(result);
    }

    [HttpPost("{id:guid}/publish")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Publish(Guid id)
    {
        var result = await _service.PublishAsync(id);
        return Ok(result);
    }

    [HttpPost("{id:guid}/unpublish")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Unpublish(Guid id)
    {
        var result = await _service.UnpublishAsync(id);
        return Ok(result);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
