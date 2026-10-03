using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Messaging;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.API.Controllers;

// Teacher <-> student / parent messages (D18). Admins have no inbox here.
[ApiController]
[Route("api/school/messages")]
[Authorize(Roles = Roles.Teacher + "," + Roles.Student + "," + Roles.Parent)]
public class MessagesController : ControllerBase
{
    private readonly IMessagingService _service;
    private readonly ProfileAccess _access;

    public MessagesController(IMessagingService service, ProfileAccess access)
    {
        _service = service;
        _access = access;
    }

    private async Task<MessagingParticipant?> MeAsync()
    {
        if (User.IsInRole(Roles.Teacher))
            return await _access.GetOwnTeacherAsync(User) is { } t
                ? new MessagingParticipant(MessageSenderRole.Teacher, t.Id, null, null, $"{t.FirstName} {t.LastName}")
                : null;
        if (User.IsInRole(Roles.Student))
            return await _access.GetOwnStudentAsync(User) is { } s
                ? new MessagingParticipant(MessageSenderRole.Student, null, s.Id, null, $"{s.FirstName} {s.LastName}")
                : null;
        return User.GetAuthUserId() is { } parentId
            ? new MessagingParticipant(MessageSenderRole.Parent, null, null, parentId, User.Identity?.Name ?? "Parent")
            : null;
    }

    [HttpGet("contacts")]
    public async Task<ActionResult> GetContacts()
        => await MeAsync() is { } me ? Ok(await _service.GetContactsAsync(me)) : Ok(Array.Empty<ContactDto>());

    [HttpGet("conversations")]
    public async Task<ActionResult> GetConversations()
        => await MeAsync() is { } me ? Ok(await _service.GetConversationsAsync(me)) : Ok(Array.Empty<ConversationDto>());

    [HttpPost("conversations")]
    public async Task<ActionResult<ConversationDto>> Start([FromBody] StartConversationDto dto)
        => await MeAsync() is { } me ? Ok(await _service.StartAsync(me, dto)) : Forbid();

    [HttpGet("conversations/{id:guid}/messages")]
    public async Task<ActionResult> GetMessages(Guid id)
        => await MeAsync() is { } me ? Ok(await _service.GetMessagesAsync(me, id)) : NotFound();

    [HttpPost("conversations/{id:guid}/messages")]
    public async Task<ActionResult<MessageDto>> Send(Guid id, [FromBody] SendMessageDto dto)
        => await MeAsync() is { } me ? StatusCode(StatusCodes.Status201Created, await _service.SendAsync(me, id, dto.Body)) : NotFound();

    [HttpPost("conversations/{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id)
    {
        if (await MeAsync() is not { } me) return NotFound();
        await _service.MarkReadAsync(me, id);
        return NoContent();
    }
}
