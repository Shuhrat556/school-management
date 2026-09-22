using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.Application.DTOs.Submissions;
using SchoolService.Application.Services;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class SubmissionsController : ControllerBase
{
    private readonly SubmissionService _submissionService;

    public SubmissionsController(SubmissionService submissionService)
    {
        _submissionService = submissionService;
    }

    [HttpGet("material/{materialId}")]
    public async Task<ActionResult<List<SubmissionResponseDto>>> GetByMaterial(Guid materialId)
    {
        return await _submissionService.GetSubmissionsByMaterialAsync(materialId);
    }

    [HttpGet("student/{studentId}")]
    public async Task<ActionResult<List<SubmissionResponseDto>>> GetByStudent(Guid studentId)
    {
        return await _submissionService.GetSubmissionsByStudentAsync(studentId);
    }

    [HttpPost]
    public async Task<ActionResult<SubmissionResponseDto>> Submit(SubmissionCreateDto dto)
    {
        // In a real app, studentId would come from the Auth context
        // For now, let's assume it's passed or handled by the service similarly
        // This is a placeholder for a real implementation
        return BadRequest("Student ID required from Auth context.");
    }

    [HttpPost("{studentId}/submit")]
    public async Task<ActionResult<SubmissionResponseDto>> Submit(Guid studentId, SubmissionCreateDto dto)
    {
        var submission = await _submissionService.SubmitAsync(studentId, dto);
        return Ok(submission);
    }

    [HttpPatch("{id}/grade")]
    public async Task<IActionResult> Grade(Guid id, GradeSubmissionDto dto)
    {
        var result = await _submissionService.GradeSubmissionAsync(id, dto);
        if (!result) return NotFound();
        return NoContent();
    }
}
