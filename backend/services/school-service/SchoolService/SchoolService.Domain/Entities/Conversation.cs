namespace SchoolService.Domain.Entities;

public enum MessageSenderRole
{
    Teacher = 1,
    Student = 2,
    Parent  = 3
}

// A one-to-one conversation between a teacher and either a student (ParentAuthUserId null)
// or one of the student's linked parents. Names are kept as they were when it started.
public class Conversation
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid TeacherId { get; private set; }
    public Guid StudentId { get; private set; }
    public Guid? ParentAuthUserId { get; private set; }
    public string TeacherName { get; private set; } = null!;
    public string StudentName { get; private set; } = null!;
    public string? ParentName { get; private set; }
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;
    public DateTime? LastMessageAt { get; private set; }

    private readonly List<Message> _messages = new();
    public IReadOnlyCollection<Message> Messages => _messages;

    private Conversation() { } // EF

    public Conversation(Guid teacherId, string teacherName, Guid studentId, string studentName,
        Guid? parentAuthUserId, string? parentName)
    {
        TeacherId        = teacherId;
        TeacherName      = teacherName;
        StudentId        = studentId;
        StudentName      = studentName;
        ParentAuthUserId = parentAuthUserId;
        ParentName       = parentName;
    }

    public Message Post(MessageSenderRole sender, string senderName, string body)
    {
        var message = new Message(Id, sender, senderName, body);
        _messages.Add(message);
        LastMessageAt = message.SentAt;
        return message;
    }
}

public class Message
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid ConversationId { get; private set; }
    public MessageSenderRole SenderRole { get; private set; }
    public string SenderName { get; private set; } = null!;
    public string Body { get; private set; } = null!;
    public DateTime SentAt { get; private set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; private set; }

    private Message() { } // EF

    public Message(Guid conversationId, MessageSenderRole senderRole, string senderName, string body)
    {
        ConversationId = conversationId;
        SenderRole     = senderRole;
        SenderName     = senderName;
        Body           = body.Trim();
    }

    public void MarkRead() => ReadAt ??= DateTime.UtcNow;
}
