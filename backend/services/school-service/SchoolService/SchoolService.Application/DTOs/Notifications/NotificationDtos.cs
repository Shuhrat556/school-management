namespace SchoolService.Application.DTOs.Notifications;

// Who is reading: a student (their own feed) or a parent account.
public record NotificationRecipient(Guid? StudentId, Guid? ParentAuthUserId)
{
    public static NotificationRecipient ForStudent(Guid studentId) => new(studentId, null);
    public static NotificationRecipient ForParent(Guid parentAuthUserId) => new(null, parentAuthUserId);
}

public class NotificationResponseDto
{
    public Guid Id { get; set; }
    public Guid StudentId { get; set; }
    public string StudentName { get; set; } = null!;
    public string Type { get; set; } = null!;
    public string Title { get; set; } = null!;
    public string Body { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public bool IsRead => ReadAt.HasValue;
}
