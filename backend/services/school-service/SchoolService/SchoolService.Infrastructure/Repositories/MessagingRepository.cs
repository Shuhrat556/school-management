using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class MessagingRepository : IMessagingRepository
{
    private readonly SchoolDbContext _context;

    public MessagingRepository(SchoolDbContext context) => _context = context;

    private IQueryable<Guid> ActiveClassIdsOf(Guid studentId)
        => _context.StudentClassrooms
            .Where(sc => sc.StudentId == studentId && sc.Status == StudentClassroomStatus.Active)
            .Select(sc => sc.ClassroomId);

    private IQueryable<Guid> ClassIdsTaughtBy(Guid teacherId)
        => _context.Classrooms.Where(c => c.TeacherId == teacherId).Select(c => c.Id)
            .Union(_context.Schedules.Where(s => s.TeacherId == teacherId && s.DeletedAt == null).Select(s => s.ClassroomId));

    public async Task<List<PersonName>> GetTeachersOfStudentAsync(Guid studentId)
    {
        var classIds = ActiveClassIdsOf(studentId);
        var teacherIds = _context.Classrooms.Where(c => classIds.Contains(c.Id) && c.TeacherId != null).Select(c => c.TeacherId!.Value)
            .Union(_context.Schedules.Where(s => classIds.Contains(s.ClassroomId) && s.TeacherId != null && s.DeletedAt == null).Select(s => s.TeacherId!.Value));
        return await _context.Teachers.AsNoTracking()
            .Where(t => teacherIds.Contains(t.Id) && t.DeletedAt == null)
            .OrderBy(t => t.FirstName).ThenBy(t => t.LastName)
            .Select(t => new PersonName(t.Id, t.FirstName + " " + t.LastName))
            .ToListAsync();
    }

    public async Task<List<PersonName>> GetStudentsOfTeacherAsync(Guid teacherId)
    {
        var classIds = ClassIdsTaughtBy(teacherId);
        var studentIds = _context.StudentClassrooms
            .Where(sc => classIds.Contains(sc.ClassroomId) && sc.Status == StudentClassroomStatus.Active)
            .Select(sc => sc.StudentId);
        return await _context.Students.AsNoTracking()
            .Where(s => studentIds.Contains(s.Id) && s.DeletedAt == null)
            .OrderBy(s => s.FirstName).ThenBy(s => s.LastName)
            .Select(s => new PersonName(s.Id, s.FirstName + " " + s.LastName))
            .ToListAsync();
    }

    public async Task<List<ParentLink>> GetParentLinksAsync(IReadOnlyCollection<Guid> studentIds)
        => await _context.StudentParents.AsNoTracking()
            .Where(p => studentIds.Contains(p.StudentId))
            .Select(p => new ParentLink(p.StudentId, p.ParentAuthUserId, p.FullName, p.Relationship))
            .ToListAsync();

    public async Task<List<ParentLink>> GetChildrenOfParentAsync(Guid parentAuthUserId)
        => await _context.StudentParents.AsNoTracking()
            .Where(p => p.ParentAuthUserId == parentAuthUserId && p.Student.DeletedAt == null)
            .Select(p => new ParentLink(p.StudentId, p.ParentAuthUserId, p.FullName, p.Relationship))
            .ToListAsync();

    public async Task<string?> GetStudentNameAsync(Guid studentId)
        => await _context.Students.AsNoTracking()
            .Where(s => s.Id == studentId)
            .Select(s => s.FirstName + " " + s.LastName)
            .FirstOrDefaultAsync();

    public async Task<Conversation?> FindAsync(Guid teacherId, Guid studentId, Guid? parentAuthUserId)
        => await _context.Conversations.FirstOrDefaultAsync(c =>
            c.TeacherId == teacherId && c.StudentId == studentId && c.ParentAuthUserId == parentAuthUserId);

    public async Task<Conversation?> GetAsync(Guid id)
        => await _context.Conversations.FirstOrDefaultAsync(c => c.Id == id);

    public async Task<List<Conversation>> ListAsync(Guid? teacherId, Guid? studentId, Guid? parentAuthUserId)
    {
        var query = _context.Conversations.AsNoTracking();
        if (teacherId.HasValue) query = query.Where(c => c.TeacherId == teacherId);
        if (studentId.HasValue) query = query.Where(c => c.StudentId == studentId && c.ParentAuthUserId == null);
        if (parentAuthUserId.HasValue) query = query.Where(c => c.ParentAuthUserId == parentAuthUserId);
        return await query.OrderByDescending(c => c.LastMessageAt ?? c.CreatedAt).ToListAsync();
    }

    public async Task<Dictionary<Guid, (string? LastBody, int Unread)>> SummariesAsync(IReadOnlyCollection<Guid> conversationIds, bool viewerIsTeacher)
    {
        var rows = await _context.Messages.AsNoTracking()
            .Where(m => conversationIds.Contains(m.ConversationId))
            .GroupBy(m => m.ConversationId)
            .Select(g => new
            {
                Id = g.Key,
                Last = g.OrderByDescending(m => m.SentAt).Select(m => m.Body).FirstOrDefault(),
                Unread = g.Count(m => m.ReadAt == null && (viewerIsTeacher ? m.SenderRole != MessageSenderRole.Teacher : m.SenderRole == MessageSenderRole.Teacher))
            })
            .ToListAsync();
        return rows.ToDictionary(r => r.Id, r => (r.Last, r.Unread));
    }

    public async Task<List<Message>> GetMessagesAsync(Guid conversationId, int take)
    {
        var latest = await _context.Messages.AsNoTracking()
            .Where(m => m.ConversationId == conversationId)
            .OrderByDescending(m => m.SentAt)
            .Take(take)
            .ToListAsync();
        latest.Reverse(); // oldest first
        return latest;
    }

    public async Task<int> CountSentSinceAsync(Guid conversationId, MessageSenderRole sender, DateTime since)
        => await _context.Messages.CountAsync(m => m.ConversationId == conversationId && m.SenderRole == sender && m.SentAt > since);

    public async Task AddConversationAsync(Conversation conversation)
    {
        await _context.Conversations.AddAsync(conversation);
        await _context.SaveChangesAsync();
    }

    public async Task AddMessageAsync(Message message, Conversation conversation)
    {
        await _context.Messages.AddAsync(message);
        _context.Conversations.Update(conversation);
        await _context.SaveChangesAsync();
    }

    public async Task MarkReadAsync(Guid conversationId, bool readerIsTeacher)
    {
        var unread = await _context.Messages
            .Where(m => m.ConversationId == conversationId && m.ReadAt == null &&
                        (readerIsTeacher ? m.SenderRole != MessageSenderRole.Teacher : m.SenderRole == MessageSenderRole.Teacher))
            .ToListAsync();
        foreach (var m in unread) m.MarkRead();
        await _context.SaveChangesAsync();
    }
}
