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

    public GradeService(
        IGradeRepository gradeRepository,
        IStudentRepository studentRepository,
        ISubjectRepository subjectRepository,
        IClassroomRepository classroomRepository)
    {
        _gradeRepository    = gradeRepository;
        _studentRepository  = studentRepository;
        _subjectRepository  = subjectRepository;
        _classroomRepository = classroomRepository;
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
            existing.UpdateScore(dto.Score, semester, (GradingMethod)dto.GradingMethod);
            await _gradeRepository.UpdateAsync(existing);
            existing = await _gradeRepository.GetByIdAsync(existing.Id) ?? existing;
            return (MapToResponse(existing), false);
        }

        var grade = new StudentGrade(
            dto.StudentId, dto.SubjectId, dto.Score, semester,
            dto.ClassroomId, (GradingMethod)dto.GradingMethod);
        await _gradeRepository.AddAsync(grade);

        grade = await _gradeRepository.GetByIdAsync(grade.Id) ?? grade;
        return (MapToResponse(grade), true);
    }

    public async Task<GradeResponseDto> UpdateAsync(Guid id, GradeUpdateDto dto)
    {
        var grade = await _gradeRepository.GetByIdAsync(id);
        if (grade == null) throw new NotFoundException("Grade", id);

        grade.UpdateScore(dto.Score, dto.Semester, (GradingMethod)dto.GradingMethod);
        await _gradeRepository.UpdateAsync(grade);
        return MapToResponse(grade);
    }

    public async Task DeleteAsync(Guid id)
    {
        var grade = await _gradeRepository.GetByIdAsync(id);
        if (grade == null) throw new NotFoundException("Grade", id);
        await _gradeRepository.DeleteAsync(grade);
    }

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
