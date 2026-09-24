using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Grades;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class GradesController : ControllerBase
{
    private readonly IGradeService _gradeService;

    public GradesController(IGradeService gradeService) => _gradeService = gradeService;

    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] Guid? studentId,
        [FromQuery] Guid? subjectId,
        [FromQuery] string? semester)
    {
        var grades = await _gradeService.GetAllAsync(studentId, subjectId, semester);
        return Ok(grades);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<GradeResponseDto>> GetById(Guid id)
    {
        var grade = await _gradeService.GetByIdAsync(id);
        return Ok(grade);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<GradeResponseDto>> Create([FromBody] GradeCreateDto dto)
    {
        var created = await _gradeService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<GradeResponseDto>> Update(Guid id, [FromBody] GradeUpdateDto dto)
    {
        var updated = await _gradeService.UpdateAsync(id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _gradeService.DeleteAsync(id);
        return NoContent();
    }
}
