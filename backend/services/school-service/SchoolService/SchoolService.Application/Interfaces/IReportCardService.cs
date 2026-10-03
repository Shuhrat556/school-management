using SchoolService.Application.DTOs.ReportCards;

namespace SchoolService.Application.Interfaces;

public interface IReportCardService
{
    // Grades of one semester (or all when null) and attendance between from and to (open when null).
    Task<ReportCardDto> GetAsync(Guid studentId, string? semester, DateOnly? from, DateOnly? to);
}
