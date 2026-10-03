using SchoolService.Application.DTOs.Grades;

namespace SchoolService.Application.Interfaces;

public interface IGradeService
{
    Task<IReadOnlyList<GradeResponseDto>> GetAllAsync(Guid? studentId, Guid? subjectId, string? semester);
    Task<GradeResponseDto> GetByIdAsync(Guid id);
    // One grade per student, subject and semester: saving again replaces the score.
    Task<(GradeResponseDto Grade, bool Created)> SaveAsync(GradeCreateDto dto);
    Task<GradeResponseDto> UpdateAsync(Guid id, GradeUpdateDto dto);
    Task DeleteAsync(Guid id);
    // Audit trail (F5): who set, changed or removed a grade.
    Task<IReadOnlyList<GradeChangeResponseDto>> GetHistoryAsync(Guid gradeId);
    Task<IReadOnlyList<GradeChangeResponseDto>> GetRecentChangesAsync(Guid? studentId, int take);
}
