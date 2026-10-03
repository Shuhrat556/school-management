using SchoolService.Application.DTOs.Notifications;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface INotificationService
{
    // Best effort: a failure is logged and never breaks the operation that triggered it.
    Task NotifyStudentAsync(Guid studentId, NotificationType type, string title, string body);
    // One recipient only: the student (parentAuthUserId null) or that one parent
    Task NotifyRecipientAsync(Guid studentId, Guid? parentAuthUserId, NotificationType type, string title, string body);
    Task NotifyClassroomAsync(Guid classroomId, NotificationType type, string title, string body);

    Task<IReadOnlyList<NotificationResponseDto>> GetFeedAsync(NotificationRecipient recipient, bool unreadOnly, int take);
    Task<int> CountUnreadAsync(NotificationRecipient recipient);
    Task MarkReadAsync(Guid id, NotificationRecipient recipient);
    Task MarkAllReadAsync(NotificationRecipient recipient);
}
