using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Submissions;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class SubmissionsController : ControllerBase
{
    private readonly ISubmissionService _submissionService;
    private readonly ProfileAccess _access;

    public SubmissionsController(ISubmissionService submissionService, ProfileAccess access)
    {
        _submissionService = submissionService;
        _access = access;
    }

    [HttpGet("material/{materialId}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<List<SubmissionResponseDto>>> GetByMaterial(Guid materialId)
    {
        return await _submissionService.GetSubmissionsByMaterialAsync(materialId);
    }

    [HttpGet("student/{studentId}")]
    public async Task<ActionResult<List<SubmissionResponseDto>>> GetByStudent(Guid studentId)
    {
        if (!await _access.CanAccessStudentAsync(User, studentId))
            return Forbid();

        return await _submissionService.GetSubmissionsByStudentAsync(studentId);
    }

    // A student hands in work for themselves; the student comes from the token.
    [HttpPost]
    public async Task<ActionResult<SubmissionResponseDto>> Submit(SubmissionCreateDto dto)
    {
        var own = await _access.GetOwnStudentAsync(User);
        if (own == null)
            return Forbid();

        return Ok(await _submissionService.SubmitAsync(own.Id, dto));
    }

    // Older clients put the student id in the path; it must be the caller's own.
    [HttpPost("{studentId}/submit")]
    public async Task<ActionResult<SubmissionResponseDto>> Submit(Guid studentId, SubmissionCreateDto dto)
    {
        var own = await _access.GetOwnStudentAsync(User);
        if (own == null || own.Id != studentId)
            return Forbid();

        return Ok(await _submissionService.SubmitAsync(own.Id, dto));
    }

    [HttpPatch("{id}/grade")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Grade(Guid id, GradeSubmissionDto dto)
    {
        var result = await _submissionService.GradeSubmissionAsync(id, dto);
        if (!result) return NotFound();
        return NoContent();
    }
}
