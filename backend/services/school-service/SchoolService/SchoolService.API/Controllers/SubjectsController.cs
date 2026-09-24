using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Subjects;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class SubjectsController : ControllerBase
{
    private readonly ISubjectService _subjectService;

    public SubjectsController(ISubjectService subjectService) => _subjectService = subjectService;

    [HttpGet]
    public async Task<ActionResult> GetAll([FromQuery] Guid? departmentId, [FromQuery] string? category, [FromQuery] string? code)
    {
        var subjects = await _subjectService.GetAllAsync();
        if (departmentId.HasValue && departmentId != Guid.Empty)
            subjects = subjects.Where(s => s.DepartmentId == departmentId).ToList();
        if (!string.IsNullOrWhiteSpace(category))
            subjects = subjects.Where(s => string.Equals(s.Category, category, StringComparison.OrdinalIgnoreCase)).ToList();
        if (!string.IsNullOrWhiteSpace(code))
            subjects = subjects.Where(s => string.Equals(s.Code, code, StringComparison.OrdinalIgnoreCase)).ToList();
        return Ok(subjects);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<SubjectResponseDto>> GetById(Guid id)
    {
        var subject = await _subjectService.GetByIdAsync(id);
        return Ok(subject);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<SubjectResponseDto>> Create([FromBody] SubjectCreateDto dto)
    {
        var created = await _subjectService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<SubjectResponseDto>> Update(Guid id, [FromBody] SubjectUpdateDto dto)
    {
        var updated = await _subjectService.UpdateAsync(id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _subjectService.DeleteAsync(id);
        return NoContent();
    }

    [HttpPost("{id:guid}/assign-teacher")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> AssignTeacher(Guid id, [FromBody] AssignTeacherToSubjectDto dto)
    {
        await _subjectService.AssignTeacherAsync(id, dto.TeacherId);
        return Ok();
    }

    [HttpDelete("{id:guid}/remove-teacher/{teacherId:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> RemoveTeacher(Guid id, Guid teacherId)
    {
        await _subjectService.RemoveTeacherAsync(id, teacherId);
        return NoContent();
    }
}
