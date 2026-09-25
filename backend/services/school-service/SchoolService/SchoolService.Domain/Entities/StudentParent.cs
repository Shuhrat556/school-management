namespace SchoolService.Domain.Entities;

// Links a parent's login account (auth-service user id) to a student. Parents
// have no school profile of their own; name and email are kept for display.
public class StudentParent
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid StudentId { get; private set; }
    public Guid ParentAuthUserId { get; private set; }
    public string FullName { get; private set; } = null!;
    public string? Email { get; private set; }
    public string? Relationship { get; private set; }
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;

    public Student Student { get; private set; } = null!;

    private StudentParent() { } // EF

    public StudentParent(Guid studentId, Guid parentAuthUserId, string fullName, string? email, string? relationship)
    {
        StudentId        = studentId;
        ParentAuthUserId = parentAuthUserId;
        UpdateDetails(fullName, email, relationship);
    }

    public void UpdateDetails(string fullName, string? email, string? relationship)
    {
        FullName     = fullName.Trim();
        Email        = string.IsNullOrWhiteSpace(email) ? null : email.Trim();
        Relationship = string.IsNullOrWhiteSpace(relationship) ? null : relationship.Trim();
    }
}
