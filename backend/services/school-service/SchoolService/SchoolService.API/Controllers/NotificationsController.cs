using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Notifications;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

// In-app notifications for students (about themselves) and parents (about their children).
[ApiController]
[Route("api/school/notifications")]
[Authorize(Roles = Roles.Student + "," + Roles.Parent)]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;
    private readonly ProfileAccess _access;

    public NotificationsController(INotificationService notificationService, ProfileAccess access)
    {
        _notificationService = notificationService;
        _access = access;
    }

    [HttpGet]
    public async Task<ActionResult> GetFeed([FromQuery] bool unreadOnly = false, [FromQuery] int take = 50)
    {
        var recipient = await ResolveRecipientAsync();
        if (recipient == null)
            return Ok(Array.Empty<NotificationResponseDto>());

        return Ok(await _notificationService.GetFeedAsync(recipient, unreadOnly, take));
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult> GetUnreadCount()
    {
        var recipient = await ResolveRecipientAsync();
        return Ok(new { count = recipient == null ? 0 : await _notificationService.CountUnreadAsync(recipient) });
    }

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id)
    {
        var recipient = await ResolveRecipientAsync();
        if (recipient == null)
            return NotFound();

        await _notificationService.MarkReadAsync(id, recipient);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead()
    {
        var recipient = await ResolveRecipientAsync();
        if (recipient != null)
            await _notificationService.MarkAllReadAsync(recipient);
        return NoContent();
    }

    private async Task<NotificationRecipient?> ResolveRecipientAsync()
    {
        if (User.IsInRole(Roles.Parent))
            return User.GetAuthUserId() is { } parentId ? NotificationRecipient.ForParent(parentId) : null;

        var student = await _access.GetOwnStudentAsync(User);
        return student == null ? null : NotificationRecipient.ForStudent(student.Id);
    }
}
