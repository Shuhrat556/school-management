namespace SchoolService.Domain.Entities;

public enum NotificationType
{
    Grade        = 1,
    Attendance   = 2,
    Announcement = 3
}

// An in-app message about a student. ParentAuthUserId == null means it is for
// the student; otherwise it is the copy for that parent account.
public class Notification
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid StudentId { get; private set; }
    public Guid? ParentAuthUserId { get; private set; }
    public NotificationType Type { get; private set; }
    public string Title { get; private set; } = null!;
    public string Body { get; private set; } = null!;
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; private set; }

    public Student Student { get; private set; } = null!;

    private Notification() { } // EF

    public Notification(Guid studentId, Guid? parentAuthUserId, NotificationType type, string title, string body)
    {
        StudentId        = studentId;
        ParentAuthUserId = parentAuthUserId;
        Type             = type;
        Title            = title.Length > 200 ? title[..200] : title;
        Body             = body.Length > 1000 ? body[..1000] : body;
    }

    public void MarkRead() => ReadAt ??= DateTime.UtcNow;
}
