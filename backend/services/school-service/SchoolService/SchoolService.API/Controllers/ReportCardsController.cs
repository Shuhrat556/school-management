using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.ReportCards;
using SchoolService.Application.Interfaces;
using SchoolService.Application.Services;

namespace SchoolService.API.Controllers;

// A student's report card: staff, the student and their linked parents.
[ApiController]
[Route("api/school/students/{studentId:guid}/report-card")]
[Authorize]
public class ReportCardsController : ControllerBase
{
    private readonly IReportCardService _reportCards;
    private readonly ProfileAccess _access;

    public ReportCardsController(IReportCardService reportCards, ProfileAccess access)
    {
        _reportCards = reportCards;
        _access = access;
    }

    [HttpGet]
    public async Task<ActionResult<ReportCardDto>> Get(
        Guid studentId, [FromQuery] string? semester, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        if (!await _access.CanAccessStudentAsync(User, studentId))
            return Forbid();
        return Ok(await _reportCards.GetAsync(studentId, semester, from, to));
    }

    [HttpGet("csv")]
    public async Task<IActionResult> GetCsv(
        Guid studentId, [FromQuery] string? semester, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        if (!await _access.CanAccessStudentAsync(User, studentId))
            return Forbid();

        var card = await _reportCards.GetAsync(studentId, semester, from, to);
        // UTF-8 with a BOM so Excel shows non-Latin names correctly.
        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(ReportCardCsv.Write(card))).ToArray();
        return File(bytes, "text/csv; charset=utf-8", FileName(card));
    }

    private static string FileName(ReportCardDto card)
    {
        var parts = new[] { "report-card", card.StudentName, card.Semester ?? "all" };
        var slug = string.Join('-', parts.Select(p => new string(p.Trim().ToLowerInvariant()
            .Select(c => char.IsLetterOrDigit(c) ? c : '-').ToArray()).Trim('-')));
        while (slug.Contains("--")) slug = slug.Replace("--", "-");
        return slug + ".csv";
    }
}
