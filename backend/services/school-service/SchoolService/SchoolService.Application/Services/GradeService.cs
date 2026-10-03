using SchoolService.Application.DTOs.Grades;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class GradeService : IGradeService
{
    private readonly IGradeRepository _gradeRepository;
    private readonly IStudentRepository _studentRepository;
    private readonly ISubjectRepository _subjectRepository;
    private readonly IClassroomRepository _classroomRepository;
    private readonly INotificationService _notifications;
    private readonly IGradeChangeRepository _gradeChanges;
    private readonly ICurrentActor _actor;

    public GradeService(
        IGradeRepository gradeRepository,
        IStudentRepository studentRepository,
        ISubjectRepository subjectRepository,
        IClassroomRepository classroomRepository,
        INotificationService notifications,
        IGradeChangeRepository gradeChanges,
        ICurrentActor actor)
    {
        _gradeRepository    = gradeRepository;
        _studentRepository  = studentRepository;
        _subjectRepository  = subjectRepository;
        _classroomRepository = classroomRepository;
        _notifications      = notifications;
        _gradeChanges       = gradeChanges;
        _actor              = actor;
    }

    public async Task<IReadOnlyList<GradeResponseDto>> GetAllAsync(Guid? studentId, Guid? subjectId, string? semester)
    {
        var grades = await _gradeRepository.GetFilteredAsync(studentId, subjectId, semester);
        return grades.Select(MapToResponse).ToList();
    }

    public async Task<GradeResponseDto> GetByIdAsync(Guid id)
    {
        var grade = await _gradeRepository.GetByIdAsync(id);
        if (grade == null) throw new NotFoundException("Grade", id);
        return MapToResponse(grade);
    }

    public async Task<(GradeResponseDto Grade, bool Created)> SaveAsync(GradeCreateDto dto)
    {
        var student = await _studentRepository.GetByIdAsync(dto.StudentId);
        if (student == null) throw new NotFoundException("Student", dto.StudentId);

        var subject = await _subjectRepository.GetByIdAsync(dto.SubjectId);
        if (subject == null) throw new NotFoundException("Subject", dto.SubjectId);

        if (dto.ClassroomId.HasValue)
        {
            var classroom = await _classroomRepository.GetByIdAsync(dto.ClassroomId.Value);
            if (classroom == null) throw new NotFoundException("Classroom", dto.ClassroomId.Value);
        }

        var semester = dto.Semester.Trim();
        var existing = await _gradeRepository.GetByStudentSubjectSemesterAsync(dto.StudentId, dto.SubjectId, semester);
        if (existing != null)
        {
            var previousScore = existing.Score;
            existing.UpdateScore(dto.Score, semester, (GradingMethod)dto.GradingMethod);
            if (previousScore != existing.Score)
                Audit(existing, GradeChangeAction.Updated, previousScore, existing.Score);
            await _gradeRepository.UpdateAsync(existing);
            if (previousScore != dto.Score)
                await _notifications.NotifyStudentAsync(dto.StudentId, NotificationType.Grade,
                    $"Grade updated in {subject.SubjectName}", $"Score {dto.Score:0.##} for semester {semester} (was {previousScore:0.##}).");
            existing = await _gradeRepository.GetByIdAsync(existing.Id) ?? existing;
            return (MapToResponse(existing), false);
        }

        var grade = new StudentGrade(
            dto.StudentId, dto.SubjectId, dto.Score, semester,
            dto.ClassroomId, (GradingMethod)dto.GradingMethod);
        Audit(grade, GradeChangeAction.Created, null, grade.Score);
        await _gradeRepository.AddAsync(grade);
        await _notifications.NotifyStudentAsync(dto.StudentId, NotificationType.Grade,
            $"New grade in {subject.SubjectName}", $"Score {dto.Score:0.##} for semester {semester}.");

        grade = await _gradeRepository.GetByIdAsync(grade.Id) ?? grade;
        return (MapToResponse(grade), true);
    }

    public async Task<GradeResponseDto> UpdateAsync(Guid id, GradeUpdateDto dto)
    {
        var grade = await _gradeRepository.GetByIdAsync(id);
        if (grade == null) throw new NotFoundException("Grade", id);

        var previousScore = grade.Score;
        var previousSemester = grade.Semester;
        grade.UpdateScore(dto.Score, dto.Semester, (GradingMethod)dto.GradingMethod);
        if (previousScore != grade.Score || previousSemester != grade.Semester)
            Audit(grade, GradeChangeAction.Updated, previousScore, grade.Score);
        await _gradeRepository.UpdateAsync(grade);
        return MapToResponse(grade);
    }

    public async Task DeleteAsync(Guid id)
    {
        var grade = await _gradeRepository.GetByIdAsync(id);
        if (grade == null) throw new NotFoundException("Grade", id);
        Audit(grade, GradeChangeAction.Deleted, grade.Score, null);
        await _gradeRepository.DeleteAsync(grade);
    }

    public async Task<IReadOnlyList<GradeChangeResponseDto>> GetHistoryAsync(Guid gradeId)
    {
        var changes = await _gradeChanges.GetByGradeAsync(gradeId);
        // Grades saved before auditing started have no history yet.
        if (changes.Count == 0 && await _gradeRepository.GetByIdAsync(gradeId) == null)
            throw new NotFoundException("Grade", gradeId);
        return changes.Select(MapToResponse).ToList();
    }

    public async Task<IReadOnlyList<GradeChangeResponseDto>> GetRecentChangesAsync(Guid? studentId, int take)
    {
        var changes = await _gradeChanges.GetRecentAsync(studentId, Math.Clamp(take, 1, 200));
        return changes.Select(MapToResponse).ToList();
    }

    // Staged on the same unit of work, so the record is saved only if the grade change is.
    private void Audit(StudentGrade grade, GradeChangeAction action, decimal? oldScore, decimal? newScore)
        => _gradeChanges.Stage(new GradeChange(grade, action, oldScore, newScore,
            _actor.AuthUserId, _actor.Name, _actor.Role));

    private static GradeChangeResponseDto MapToResponse(GradeChangeEntry entry) => new()
    {
        Id                  = entry.Change.Id,
        GradeId             = entry.Change.GradeId,
        StudentId           = entry.Change.StudentId,
        StudentName         = entry.StudentName,
        SubjectId           = entry.Change.SubjectId,
        SubjectName         = entry.SubjectName,
        Semester            = entry.Change.Semester,
        Action              = entry.Change.Action.ToString(),
        OldScore            = entry.Change.OldScore,
        NewScore            = entry.Change.NewScore,
        ChangedByAuthUserId = entry.Change.ChangedByAuthUserId,
        ChangedByName       = entry.Change.ChangedByName,
        ChangedByRole       = entry.Change.ChangedByRole,
        ChangedAt           = entry.Change.ChangedAt
    };

    private static GradeResponseDto MapToResponse(StudentGrade g) => new()
    {
        Id                = g.Id,
        StudentId         = g.StudentId,
        StudentName       = g.Student != null ? $"{g.Student.FirstName} {g.Student.LastName}" : "",
        SubjectId         = g.SubjectId,
        SubjectName       = g.Subject?.SubjectName ?? "",
        ClassroomId       = g.ClassroomId,
        ClassroomName     = g.Classroom?.Name,
        Score             = g.Score,
        Semester          = g.Semester,
        GradingMethod     = (int)g.GradingMethod,
        GradingMethodName = g.GradingMethod.ToString(),
        CreatedAt         = g.CreatedAt
    };
}
