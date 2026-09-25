using Microsoft.EntityFrameworkCore;
using SchoolService.Application.DTOs.Notifications;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class NotificationRepository : INotificationRepository
{
    private readonly SchoolDbContext _context;

    public NotificationRepository(SchoolDbContext context)
    {
        _context = context;
    }

    private IQueryable<Notification> For(NotificationRecipient recipient)
        => recipient.ParentAuthUserId is { } parentId
            ? _context.Notifications.Where(n => n.ParentAuthUserId == parentId)
            : _context.Notifications.Where(n => n.StudentId == recipient.StudentId && n.ParentAuthUserId == null);

    public async Task AddRangeAsync(IEnumerable<Notification> notifications)
    {
        await _context.Notifications.AddRangeAsync(notifications);
        await _context.SaveChangesAsync();
    }

    public async Task<List<Notification>> GetFeedAsync(NotificationRecipient recipient, bool unreadOnly, int take)
        => await For(recipient)
            .Where(n => !unreadOnly || n.ReadAt == null)
            .Include(n => n.Student)
            .OrderByDescending(n => n.CreatedAt)
            .Take(take)
            .AsNoTracking()
            .ToListAsync();

    public async Task<int> CountUnreadAsync(NotificationRecipient recipient)
        => await For(recipient).CountAsync(n => n.ReadAt == null);

    public async Task<Notification?> GetAsync(Guid id, NotificationRecipient recipient)
        => await For(recipient).FirstOrDefaultAsync(n => n.Id == id);

    public async Task UpdateAsync(Notification notification)
    {
        _context.Notifications.Update(notification);
        await _context.SaveChangesAsync();
    }

    public async Task MarkAllReadAsync(NotificationRecipient recipient)
    {
        var now = DateTime.UtcNow;
        await For(recipient)
            .Where(n => n.ReadAt == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(n => n.ReadAt, now));
    }
}
