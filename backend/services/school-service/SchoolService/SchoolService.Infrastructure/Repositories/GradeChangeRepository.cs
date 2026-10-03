using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class GradeChangeRepository : IGradeChangeRepository
{
    private readonly SchoolDbContext _context;

    public GradeChangeRepository(SchoolDbContext context)
    {
        _context = context;
    }

    public void Stage(GradeChange change) => _context.GradeChanges.Add(change);

    public async Task<List<GradeChangeEntry>> GetByGradeAsync(Guid gradeId)
        => await WithNames(_context.GradeChanges.Where(c => c.GradeId == gradeId), newestFirst: false)
            .ToListAsync();

    public async Task<List<GradeChangeEntry>> GetRecentAsync(Guid? studentId, int take)
        => await WithNames(_context.GradeChanges.Where(c => studentId == null || c.StudentId == studentId), newestFirst: true)
            .Take(take)
            .ToListAsync();

    // Left joins: the history stays readable after a grade's student or subject is removed.
    // Soft-deleted students keep their names here on purpose.
    private IQueryable<GradeChangeEntry> WithNames(IQueryable<GradeChange> changes, bool newestFirst)
    {
        var rows = from c in changes.AsNoTracking()
                   join s in _context.Students on c.StudentId equals s.Id into students
                   from s in students.DefaultIfEmpty()
                   join sub in _context.Subjects on c.SubjectId equals sub.Id into subjects
                   from sub in subjects.DefaultIfEmpty()
                   select new { Change = c, Student = s, Subject = sub };

        rows = newestFirst ? rows.OrderByDescending(r => r.Change.ChangedAt) : rows.OrderBy(r => r.Change.ChangedAt);

        return rows.Select(r => new GradeChangeEntry(
            r.Change,
            r.Student == null ? null : r.Student.FirstName + " " + r.Student.LastName,
            r.Subject == null ? null : r.Subject.SubjectName));
    }
}
