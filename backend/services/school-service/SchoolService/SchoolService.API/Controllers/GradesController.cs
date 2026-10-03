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
    private readonly ProfileAccess _access;

    public GradesController(IGradeService gradeService, ProfileAccess access)
    {
        _gradeService = gradeService;
        _access = access;
    }

    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] Guid? studentId,
        [FromQuery] Guid? subjectId,
        [FromQuery] string? semester)
    {
        // A parent picks one of their children; a student only ever sees their own grades.
        if (User.IsInRole(Roles.Parent))
        {
            if (!studentId.HasValue || !await _access.CanAccessStudentAsync(User, studentId.Value))
                return Forbid();
        }
        else if (!User.IsStaff())
        {
            var own = await _access.GetOwnStudentAsync(User);
            if (own == null || (studentId.HasValue && studentId != own.Id))
                return Forbid();
            studentId = own.Id;
        }

        var grades = await _gradeService.GetAllAsync(studentId, subjectId, semester);
        return Ok(grades);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<GradeResponseDto>> GetById(Guid id)
    {
        var grade = await _gradeService.GetByIdAsync(id);
        if (!await _access.CanAccessStudentAsync(User, grade.StudentId))
            return Forbid();
        return Ok(grade);
    }

    [HttpGet("{id:guid}/history")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<IReadOnlyList<GradeChangeResponseDto>>> GetHistory(Guid id)
        => Ok(await _gradeService.GetHistoryAsync(id));

    // School-wide audit feed, newest first.
    [HttpGet("changes")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<IReadOnlyList<GradeChangeResponseDto>>> GetRecentChanges(
        [FromQuery] Guid? studentId,
        [FromQuery] int take = 50)
        => Ok(await _gradeService.GetRecentChangesAsync(studentId, take));

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<GradeResponseDto>> Create([FromBody] GradeCreateDto dto)
    {
        // Saving a grade that already exists for the student, subject and semester updates it.
        var (grade, created) = await _gradeService.SaveAsync(dto);
        return created ? CreatedAtAction(nameof(GetById), new { id = grade.Id }, grade) : Ok(grade);
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
