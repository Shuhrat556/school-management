using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public sealed record PersonName(Guid Id, string Name);
public sealed record ParentLink(Guid StudentId, Guid ParentAuthUserId, string FullName, string? Relationship);

public interface IMessagingRepository
{
    // Teachers of the student's current classes (class teacher or a teacher on its timetable)
    Task<List<PersonName>> GetTeachersOfStudentAsync(Guid studentId);
    // Students currently in the classes the teacher teaches
    Task<List<PersonName>> GetStudentsOfTeacherAsync(Guid teacherId);
    Task<List<ParentLink>> GetParentLinksAsync(IReadOnlyCollection<Guid> studentIds);
    Task<List<ParentLink>> GetChildrenOfParentAsync(Guid parentAuthUserId);
    Task<string?> GetStudentNameAsync(Guid studentId);

    Task<Conversation?> FindAsync(Guid teacherId, Guid studentId, Guid? parentAuthUserId);
    Task<Conversation?> GetAsync(Guid id);
    Task<List<Conversation>> ListAsync(Guid? teacherId, Guid? studentId, Guid? parentAuthUserId);
    Task<Dictionary<Guid, (string? LastBody, int Unread)>> SummariesAsync(IReadOnlyCollection<Guid> conversationIds, bool viewerIsTeacher);
    Task<List<Message>> GetMessagesAsync(Guid conversationId, int take);
    Task<int> CountSentSinceAsync(Guid conversationId, MessageSenderRole sender, DateTime since);
    Task AddConversationAsync(Conversation conversation);
    Task AddMessageAsync(Message message, Conversation conversation);
    Task MarkReadAsync(Guid conversationId, bool readerIsTeacher);
}
