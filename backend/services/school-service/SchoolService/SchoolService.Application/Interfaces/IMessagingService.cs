using SchoolService.Application.DTOs.Messaging;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

// Who is calling: a teacher (TeacherId), a student (StudentId) or a parent (ParentAuthUserId).
public sealed record MessagingParticipant(MessageSenderRole Role, Guid? TeacherId, Guid? StudentId, Guid? ParentAuthUserId, string Name);

public interface IMessagingService
{
    Task<IReadOnlyList<ContactDto>> GetContactsAsync(MessagingParticipant me);
    Task<IReadOnlyList<ConversationDto>> GetConversationsAsync(MessagingParticipant me);
    // Finds or starts the conversation; only along class relationships (else ForbiddenException)
    Task<ConversationDto> StartAsync(MessagingParticipant me, StartConversationDto dto);
    Task<IReadOnlyList<MessageDto>> GetMessagesAsync(MessagingParticipant me, Guid conversationId);
    Task<MessageDto> SendAsync(MessagingParticipant me, Guid conversationId, string body);
    Task MarkReadAsync(MessagingParticipant me, Guid conversationId);
}
