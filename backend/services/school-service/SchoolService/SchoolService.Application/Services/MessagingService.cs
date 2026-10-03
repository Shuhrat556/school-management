using SchoolService.Application.DTOs.Messaging;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

// Teacher <-> student and teacher <-> parent messages (D18). A teacher reaches the students
// they teach and those students' linked parents; a student or parent reaches the teachers of
// their (child's) current classes. Nobody else, and no student-to-student messages.
public class MessagingService : IMessagingService
{
    private const int MessagesPerMinute = 20;
    private const int ThreadLength = 200;

    private readonly IMessagingRepository _repo;
    private readonly INotificationService _notifications;

    public MessagingService(IMessagingRepository repo, INotificationService notifications)
    {
        _repo = repo;
        _notifications = notifications;
    }

    public async Task<IReadOnlyList<ContactDto>> GetContactsAsync(MessagingParticipant me)
    {
        switch (me.Role)
        {
            case MessageSenderRole.Teacher:
            {
                var students = await _repo.GetStudentsOfTeacherAsync(me.TeacherId!.Value);
                var names = students.ToDictionary(s => s.Id, s => s.Name);
                var parents = await _repo.GetParentLinksAsync(names.Keys.ToList());
                return students
                    .Select(s => new ContactDto { Kind = "Student", Name = s.Name, StudentId = s.Id })
                    .Concat(parents.Select(p => new ContactDto
                    {
                        Kind = "Parent",
                        Name = p.FullName,
                        Context = $"{p.Relationship ?? "Parent"} of {names[p.StudentId]}",
                        StudentId = p.StudentId,
                        ParentAuthUserId = p.ParentAuthUserId
                    }))
                    .ToList();
            }
            case MessageSenderRole.Student:
                return (await _repo.GetTeachersOfStudentAsync(me.StudentId!.Value))
                    .Select(t => new ContactDto { Kind = "Teacher", Name = t.Name, TeacherId = t.Id, StudentId = me.StudentId })
                    .ToList();
            default:
            {
                var contacts = new List<ContactDto>();
                foreach (var child in await _repo.GetChildrenOfParentAsync(me.ParentAuthUserId!.Value))
                {
                    var childName = await _repo.GetStudentNameAsync(child.StudentId) ?? "";
                    contacts.AddRange((await _repo.GetTeachersOfStudentAsync(child.StudentId)).Select(t => new ContactDto
                    {
                        Kind = "Teacher",
                        Name = t.Name,
                        Context = $"Teacher of {childName}",
                        TeacherId = t.Id,
                        StudentId = child.StudentId
                    }));
                }
                return contacts;
            }
        }
    }

    public async Task<IReadOnlyList<ConversationDto>> GetConversationsAsync(MessagingParticipant me)
    {
        var conversations = me.Role switch
        {
            MessageSenderRole.Teacher => await _repo.ListAsync(me.TeacherId, null, null),
            MessageSenderRole.Student => await _repo.ListAsync(null, me.StudentId, null),
            _ => await _repo.ListAsync(null, null, me.ParentAuthUserId)
        };
        if (me.Role == MessageSenderRole.Parent)
        {
            // A parent unlinked from the child loses those conversations
            var children = (await _repo.GetChildrenOfParentAsync(me.ParentAuthUserId!.Value)).Select(c => c.StudentId).ToHashSet();
            conversations = conversations.Where(c => children.Contains(c.StudentId)).ToList();
        }
        var summaries = await _repo.SummariesAsync(conversations.Select(c => c.Id).ToList(), me.Role == MessageSenderRole.Teacher);
        return conversations.Select(c => MapToDto(me, c, summaries.GetValueOrDefault(c.Id))).ToList();
    }

    public async Task<ConversationDto> StartAsync(MessagingParticipant me, StartConversationDto dto)
    {
        Guid teacherId, studentId;
        Guid? parentId = null;
        string? parentName = null;

        switch (me.Role)
        {
            case MessageSenderRole.Teacher:
                teacherId = me.TeacherId!.Value;
                studentId = dto.StudentId ?? throw new ValidationException("Choose the student.");
                if ((await _repo.GetStudentsOfTeacherAsync(teacherId)).All(s => s.Id != studentId))
                    throw new ForbiddenException("You can only write to students in your classes and their parents.");
                if (dto.ParentAuthUserId is { } parentAuthUserId)
                {
                    var link = (await _repo.GetParentLinksAsync([studentId])).FirstOrDefault(p => p.ParentAuthUserId == parentAuthUserId)
                        ?? throw new ForbiddenException("That parent is not linked to this student.");
                    parentId = link.ParentAuthUserId;
                    parentName = link.FullName;
                }
                break;
            case MessageSenderRole.Student:
                studentId = me.StudentId!.Value;
                teacherId = dto.TeacherId ?? throw new ValidationException("Choose the teacher.");
                if ((await _repo.GetTeachersOfStudentAsync(studentId)).All(t => t.Id != teacherId))
                    throw new ForbiddenException("You can only write to the teachers of your classes.");
                break;
            default:
                teacherId = dto.TeacherId ?? throw new ValidationException("Choose the teacher.");
                studentId = dto.StudentId ?? throw new ValidationException("Choose which child this is about.");
                var child = (await _repo.GetChildrenOfParentAsync(me.ParentAuthUserId!.Value)).FirstOrDefault(c => c.StudentId == studentId)
                    ?? throw new ForbiddenException("You can only write about your own children.");
                if ((await _repo.GetTeachersOfStudentAsync(studentId)).All(t => t.Id != teacherId))
                    throw new ForbiddenException("You can only write to your child's teachers.");
                parentId = child.ParentAuthUserId;
                parentName = child.FullName;
                break;
        }

        var conversation = await _repo.FindAsync(teacherId, studentId, parentId);
        if (conversation == null)
        {
            var teacherName = (await _repo.GetTeachersOfStudentAsync(studentId)).FirstOrDefault(t => t.Id == teacherId)?.Name
                ?? me.Name;
            conversation = new Conversation(teacherId, teacherName, studentId, await _repo.GetStudentNameAsync(studentId) ?? "", parentId, parentName);
            await _repo.AddConversationAsync(conversation);
        }
        var summary = (await _repo.SummariesAsync([conversation.Id], me.Role == MessageSenderRole.Teacher)).GetValueOrDefault(conversation.Id);
        return MapToDto(me, conversation, summary);
    }

    public async Task<IReadOnlyList<MessageDto>> GetMessagesAsync(MessagingParticipant me, Guid conversationId)
    {
        await GetOwnAsync(me, conversationId);
        return (await _repo.GetMessagesAsync(conversationId, ThreadLength)).Select(m => MapToDto(me, m)).ToList();
    }

    public async Task<MessageDto> SendAsync(MessagingParticipant me, Guid conversationId, string body)
    {
        var conversation = await GetOwnAsync(me, conversationId);
        if (await _repo.CountSentSinceAsync(conversationId, me.Role, DateTime.UtcNow.AddMinutes(-1)) >= MessagesPerMinute)
            throw new TooManyRequestsException("Too many messages in a minute. Please wait a moment.");

        var message = conversation.Post(me.Role, me.Name, body);
        await _repo.AddMessageAsync(message, conversation);

        // The family hears about a teacher's message; teachers see unread counts in their inbox
        if (me.Role == MessageSenderRole.Teacher)
            await _notifications.NotifyRecipientAsync(conversation.StudentId, conversation.ParentAuthUserId, NotificationType.Message,
                $"New message from {conversation.TeacherName}", message.Body.Length > 140 ? message.Body[..140] + "…" : message.Body);

        return MapToDto(me, message);
    }

    public async Task MarkReadAsync(MessagingParticipant me, Guid conversationId)
    {
        await GetOwnAsync(me, conversationId);
        await _repo.MarkReadAsync(conversationId, me.Role == MessageSenderRole.Teacher);
    }

    // A conversation the caller takes part in; anyone else gets "not found"
    private async Task<Conversation> GetOwnAsync(MessagingParticipant me, Guid conversationId)
    {
        var c = await _repo.GetAsync(conversationId);
        var mine = c != null && me.Role switch
        {
            MessageSenderRole.Teacher => c.TeacherId == me.TeacherId,
            MessageSenderRole.Student => c.StudentId == me.StudentId && c.ParentAuthUserId == null,
            _ => c.ParentAuthUserId == me.ParentAuthUserId
                 && (await _repo.GetChildrenOfParentAsync(me.ParentAuthUserId!.Value)).Any(ch => ch.StudentId == c.StudentId)
        };
        return mine ? c! : throw new NotFoundException("Conversation", conversationId);
    }

    private static ConversationDto MapToDto(MessagingParticipant me, Conversation c, (string? LastBody, int Unread) summary) => new()
    {
        Id = c.Id,
        Title = me.Role == MessageSenderRole.Teacher ? c.ParentName ?? c.StudentName : c.TeacherName,
        Subtitle = me.Role == MessageSenderRole.Teacher
            ? (c.ParentName != null ? $"Parent of {c.StudentName}" : "Student")
            : (me.Role == MessageSenderRole.Parent ? $"About {c.StudentName}" : "Teacher"),
        TeacherId = c.TeacherId,
        StudentId = c.StudentId,
        ParentAuthUserId = c.ParentAuthUserId,
        LastMessage = summary.LastBody,
        LastMessageAt = c.LastMessageAt,
        UnreadCount = summary.Unread
    };

    private static MessageDto MapToDto(MessagingParticipant me, Message m) => new()
    {
        Id = m.Id,
        SenderRole = m.SenderRole.ToString(),
        SenderName = m.SenderName,
        Body = m.Body,
        SentAt = DateTime.SpecifyKind(m.SentAt, DateTimeKind.Utc),
        ReadAt = m.ReadAt,
        IsMine = m.SenderRole == me.Role
    };
}
