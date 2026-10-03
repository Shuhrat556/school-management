using System.ComponentModel.DataAnnotations;

namespace SchoolService.Application.DTOs.Messaging;

public class ContactDto
{
    /// <summary>"Teacher", "Student" or "Parent".</summary>
    public string Kind { get; set; } = null!;
    public string Name { get; set; } = null!;
    /// <summary>Who this is for the caller, e.g. "Parent of Nodira Aliyeva".</summary>
    public string? Context { get; set; }
    public Guid? TeacherId { get; set; }
    public Guid? StudentId { get; set; }
    public Guid? ParentAuthUserId { get; set; }
}

public class StartConversationDto
{
    /// <summary>Required for students and parents: the teacher to write to.</summary>
    public Guid? TeacherId { get; set; }
    /// <summary>Required for teachers and parents: the student the conversation is about.</summary>
    public Guid? StudentId { get; set; }
    /// <summary>Teachers only: write to this linked parent instead of the student.</summary>
    public Guid? ParentAuthUserId { get; set; }
}

public class SendMessageDto
{
    [Required]
    [StringLength(2000, MinimumLength = 1)]
    public string Body { get; set; } = null!;
}

public class ConversationDto
{
    public Guid Id { get; set; }
    /// <summary>The other person's name, as the caller sees it.</summary>
    public string Title { get; set; } = null!;
    public string? Subtitle { get; set; }
    public Guid TeacherId { get; set; }
    public Guid StudentId { get; set; }
    public Guid? ParentAuthUserId { get; set; }
    public string? LastMessage { get; set; }
    public DateTime? LastMessageAt { get; set; }
    public int UnreadCount { get; set; }
}

public class MessageDto
{
    public Guid Id { get; set; }
    /// <summary>"Teacher", "Student" or "Parent".</summary>
    public string SenderRole { get; set; } = null!;
    public string SenderName { get; set; } = null!;
    public string Body { get; set; } = null!;
    public DateTime SentAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public bool IsMine { get; set; }
}
