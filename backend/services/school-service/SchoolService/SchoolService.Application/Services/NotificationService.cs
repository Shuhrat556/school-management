using Microsoft.Extensions.Logging;
using SchoolService.Application.DTOs.Notifications;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class NotificationService : INotificationService
{
    private readonly INotificationRepository _notifications;
    private readonly IStudentParentRepository _parents;
    private readonly IClassroomRepository _classrooms;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        INotificationRepository notifications,
        IStudentParentRepository parents,
        IClassroomRepository classrooms,
        ILogger<NotificationService> logger)
    {
        _notifications = notifications;
        _parents = parents;
        _classrooms = classrooms;
        _logger = logger;
    }

    public async Task NotifyStudentAsync(Guid studentId, NotificationType type, string title, string body)
    {
        try
        {
            await _notifications.AddRangeAsync(await BuildAsync(studentId, type, title, body));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not create {Type} notification for student {StudentId}", type, studentId);
        }
    }

    public async Task NotifyClassroomAsync(Guid classroomId, NotificationType type, string title, string body)
    {
        try
        {
            var classroom = await _classrooms.GetByIdWithDetailsAsync(classroomId);
            if (classroom == null) return;

            var notifications = new List<Notification>();
            var studentIds = classroom.StudentClassrooms
                .Where(sc => sc.Status == StudentClassroomStatus.Active && sc.Student?.DeletedAt == null)
                .Select(sc => sc.StudentId)
                .Distinct();
            foreach (var studentId in studentIds)
                notifications.AddRange(await BuildAsync(studentId, type, title, body));

            if (notifications.Count > 0)
                await _notifications.AddRangeAsync(notifications);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not create {Type} notifications for classroom {ClassroomId}", type, classroomId);
        }
    }

    // One copy for the student and one for each linked parent
    public async Task NotifyRecipientAsync(Guid studentId, Guid? parentAuthUserId, NotificationType type, string title, string body)
    {
        try
        {
            await _notifications.AddRangeAsync([new Notification(studentId, parentAuthUserId, type, title, body)]);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not create {Type} notification for student {StudentId}", type, studentId);
        }
    }

    private async Task<List<Notification>> BuildAsync(Guid studentId, NotificationType type, string title, string body)
    {
        var notifications = new List<Notification> { new(studentId, null, type, title, body) };
        foreach (var parent in await _parents.GetByStudentAsync(studentId))
            notifications.Add(new Notification(studentId, parent.ParentAuthUserId, type, title, body));
        return notifications;
    }

    public async Task<IReadOnlyList<NotificationResponseDto>> GetFeedAsync(NotificationRecipient recipient, bool unreadOnly, int take)
    {
        var feed = await _notifications.GetFeedAsync(recipient, unreadOnly, Math.Clamp(take, 1, 200));
        return feed.Select(MapToResponse).ToList();
    }

    public Task<int> CountUnreadAsync(NotificationRecipient recipient)
        => _notifications.CountUnreadAsync(recipient);

    public async Task MarkReadAsync(Guid id, NotificationRecipient recipient)
    {
        var notification = await _notifications.GetAsync(id, recipient)
            ?? throw new NotFoundException("Notification", id);
        notification.MarkRead();
        await _notifications.UpdateAsync(notification);
    }

    public Task MarkAllReadAsync(NotificationRecipient recipient)
        => _notifications.MarkAllReadAsync(recipient);

    private static NotificationResponseDto MapToResponse(Notification n) => new()
    {
        Id          = n.Id,
        StudentId   = n.StudentId,
        StudentName = n.Student != null ? $"{n.Student.FirstName} {n.Student.LastName}" : "",
        Type        = n.Type.ToString(),
        Title       = n.Title,
        Body        = n.Body,
        CreatedAt   = n.CreatedAt,
        ReadAt      = n.ReadAt
    };
}
