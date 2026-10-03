using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

// An audit record with the student's and subject's current names (null once they are gone).
public sealed record GradeChangeEntry(GradeChange Change, string? StudentName, string? SubjectName);

public interface IGradeChangeRepository
{
    // Adds the record without saving, so it is committed together with the grade change.
    void Stage(GradeChange change);
    Task<List<GradeChangeEntry>> GetByGradeAsync(Guid gradeId);
    Task<List<GradeChangeEntry>> GetRecentAsync(Guid? studentId, int take);
}
