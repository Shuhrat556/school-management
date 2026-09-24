using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Schedules;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class SchedulesController : ControllerBase
{
    private readonly IScheduleService _scheduleService;

    public SchedulesController(IScheduleService scheduleService) => _scheduleService = scheduleService;

    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] Guid? classroomId,
        [FromQuery] Guid? teacherId)
    {
        if (teacherId.HasValue)
            return Ok(await _scheduleService.GetByTeacherAsync(teacherId.Value));

        if (classroomId.HasValue)
            return Ok(await _scheduleService.GetByClassroomAsync(classroomId.Value));

        return BadRequest(new { message = "Provide classroomId or teacherId query parameter." });
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ScheduleResponseDto>> GetById(Guid id)
    {
        var schedule = await _scheduleService.GetByIdAsync(id);
        return Ok(schedule);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<ScheduleResponseDto>> Create([FromBody] ScheduleCreateDto dto)
    {
        var created = await _scheduleService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<ScheduleResponseDto>> Update(Guid id, [FromBody] ScheduleUpdateDto dto)
    {
        var updated = await _scheduleService.UpdateAsync(id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _scheduleService.DeleteAsync(id);
        return NoContent();
    }
}
