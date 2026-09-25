using SchoolService.Application.DTOs.Notifications;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface INotificationRepository
{
    Task AddRangeAsync(IEnumerable<Notification> notifications);
    Task<List<Notification>> GetFeedAsync(NotificationRecipient recipient, bool unreadOnly, int take);
    Task<int> CountUnreadAsync(NotificationRecipient recipient);
    Task<Notification?> GetAsync(Guid id, NotificationRecipient recipient);
    Task UpdateAsync(Notification notification);
    Task MarkAllReadAsync(NotificationRecipient recipient);
}
