namespace SchoolService.Domain.Entities;

public enum GradeChangeAction
{
    Created = 1,
    Updated = 2,
    Deleted = 3
}

// Append-only audit record: who set, changed or removed a grade, and when.
// No foreign keys, so the history outlives the grade itself.
public class GradeChange
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid GradeId { get; private set; }
    public Guid StudentId { get; private set; }
    public Guid SubjectId { get; private set; }
    public string Semester { get; private set; } = null!;
    public GradeChangeAction Action { get; private set; }
    public decimal? OldScore { get; private set; }
    public decimal? NewScore { get; private set; }
    public Guid? ChangedByAuthUserId { get; private set; }
    public string? ChangedByName { get; private set; }
    public string? ChangedByRole { get; private set; }
    public DateTime ChangedAt { get; private set; } = DateTime.UtcNow;

    private GradeChange() { } // EF

    public GradeChange(StudentGrade grade, GradeChangeAction action, decimal? oldScore, decimal? newScore,
        Guid? changedByAuthUserId, string? changedByName, string? changedByRole)
    {
        GradeId             = grade.Id;
        StudentId           = grade.StudentId;
        SubjectId           = grade.SubjectId;
        Semester            = grade.Semester;
        Action              = action;
        OldScore            = oldScore;
        NewScore            = newScore;
        ChangedByAuthUserId = changedByAuthUserId;
        ChangedByName       = changedByName;
        ChangedByRole       = changedByRole;
    }
}
