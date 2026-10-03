using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Classrooms;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class ClassroomService : IClassroomService
{
    private readonly IClassroomRepository _classroomRepository;
    private readonly IStudentRepository _studentRepository;

    public ClassroomService(
        IClassroomRepository classroomRepository,
        IStudentRepository studentRepository)
    {
        _classroomRepository = classroomRepository;
        _studentRepository = studentRepository;
    }

    public async Task<IReadOnlyList<ClassroomResponseDto>> GetAllAsync()
    {
        var classrooms = await _classroomRepository.GetAllAsync();
        return classrooms
            .Select(MapToResponseSafe)
            .ToList();
    }

    public async Task<PagedResult<ClassroomResponseDto>> GetAllAsync(int page, int pageSize)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var (items, total) = await _classroomRepository.GetPagedAsync(page, pageSize);
        return new PagedResult<ClassroomResponseDto>
        {
            Items = items.Select(MapToResponseSafe).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<ClassroomDetailResponseDto> GetByIdAsync(Guid id)
    {
        var classroom = await _classroomRepository.GetByIdWithDetailsAsync(id);
        if (classroom == null)
            throw new NotFoundException("Classroom", id);

        return MapToDetailResponse(classroom);
    }

    public async Task<IReadOnlyList<ClassroomResponseDto>> GetByStudentIdAsync(Guid studentId)
    {
        var classrooms = await _classroomRepository.GetByStudentIdAsync(studentId);
        return classrooms.Select(MapToResponseSafe).ToList();
    }

    public async Task<ClassroomResponseDto> CreateAsync(ClassroomCreateDto dto)
    {
        var classroom = new Classroom(dto.Name, dto.SubjectId);
        classroom.UpdateInfo(dto.Name, dto.Grade, dto.AcademicYear, dto.Semester, dto.RoomId);
        classroom.AssignTeacher(dto.TeacherId);

        await _classroomRepository.AddAsync(classroom);
        
        var createdClassroom = await _classroomRepository.GetByIdWithDetailsAsync(classroom.Id);
        if (createdClassroom == null)
            throw new Exception("Failed to retrieve the created classroom.");
        return MapToResponse(createdClassroom);
    }

    public async Task<ClassroomResponseDto> UpdateAsync(Guid id, ClassroomUpdateDto dto)
    {
        var classroom = await _classroomRepository.GetByIdAsync(id);
        if (classroom == null)
            throw new NotFoundException("Classroom", id);

        classroom.UpdateInfo(dto.Name, dto.Grade, dto.AcademicYear, dto.Semester, dto.RoomId);
        classroom.AssignTeacher(dto.TeacherId);

        if (dto.IsActive)
            classroom.Activate();
        else
            classroom.Deactivate();

        await _classroomRepository.UpdateAsync(classroom);
        
        var updatedClassroom = await _classroomRepository.GetByIdWithDetailsAsync(id);
        if (updatedClassroom == null)
            throw new Exception("Failed to retrieve the updated classroom.");
        return MapToResponse(updatedClassroom);
    }

    public async Task DeleteAsync(Guid id)
    {
        var classroom = await _classroomRepository.GetByIdAsync(id);
        if (classroom == null)
            throw new NotFoundException("Classroom", id);

        await _classroomRepository.DeleteAsync(classroom);
    }

    public async Task EnrollStudentAsync(Guid classroomId, Guid studentId)
    {
        var classroom = await _classroomRepository.GetByIdAsync(classroomId);
        if (classroom == null)
            throw new NotFoundException("Classroom", classroomId);

        var student = await _studentRepository.GetByIdAsync(studentId);
        if (student == null)
            throw new NotFoundException("Student", studentId);

        var existing = await _classroomRepository.GetEnrollmentAsync(classroomId, studentId);
        if (existing?.Status == StudentClassroomStatus.Active)
            throw new DuplicateException($"Student '{studentId}' is already enrolled in classroom '{classroomId}'.");

        // One row per student and classroom (composite key): a student who left comes back on the same row.
        if (existing != null)
        {
            existing.Reenroll();
            await _classroomRepository.UpdateEnrollmentAsync(existing);
            return;
        }

        var enrollment = new StudentClassroom(studentId, classroomId);
        await _classroomRepository.AddEnrollmentAsync(enrollment);
    }

    public async Task UnenrollStudentAsync(Guid classroomId, Guid studentId)
    {
        var enrollment = await _classroomRepository.GetEnrollmentAsync(classroomId, studentId);
        if (enrollment?.Status != StudentClassroomStatus.Active)
            throw new NotFoundException($"No enrollment found for student '{studentId}' in classroom '{classroomId}'.");

        enrollment.Drop();
        await _classroomRepository.UpdateEnrollmentAsync(enrollment);
    }

    public async Task<bool> IsActiveMemberAsync(Guid classroomId, Guid studentId)
        => (await _classroomRepository.GetEnrollmentAsync(classroomId, studentId))?.Status == StudentClassroomStatus.Active;

    private static ClassroomResponseDto MapToResponse(Classroom c) => new()
    {
        Id           = c.Id,
        Name         = c.Name,
        Grade        = c.Grade,
        AcademicYear = c.AcademicYear,
        Semester     = c.Semester,
        RoomId       = c.RoomId,
        RoomName     = c.Room?.Name,
        TeacherId    = c.TeacherId,
        TeacherName  = c.Teacher != null ? $"{c.Teacher.FirstName} {c.Teacher.LastName}" : null,
        SubjectId    = c.SubjectId,
        SubjectName  = c.Subject.SubjectName,
        IsActive     = c.IsActive,
        CreatedAt    = c.CreatedAt,
        StudentCount = c.StudentClassrooms.Count(sc => sc.Status == StudentClassroomStatus.Active)
    };

    private static ClassroomResponseDto MapToResponseSafe(Classroom c) => new()
    {
        Id           = c.Id,
        Name         = c.Name,
        Grade        = c.Grade,
        AcademicYear = c.AcademicYear,
        Semester     = c.Semester,
        RoomId       = c.RoomId,
        RoomName     = c.Room?.Name,
        TeacherId    = c.TeacherId,
        TeacherName  = c.Teacher != null ? $"{c.Teacher.FirstName} {c.Teacher.LastName}" : null,
        SubjectId    = c.SubjectId,
        SubjectName  = c.Subject?.SubjectName ?? "Unknown Subject",
        IsActive     = c.IsActive,
        CreatedAt    = c.CreatedAt,
        StudentCount = c.StudentClassrooms.Count(sc => sc.Status == StudentClassroomStatus.Active)
    };

    private static ClassroomDetailResponseDto MapToDetailResponse(Classroom c) => new()
    {
        Id           = c.Id,
        Name         = c.Name,
        Grade        = c.Grade,
        AcademicYear = c.AcademicYear,
        TeacherId    = c.TeacherId,
        TeacherName  = c.Teacher != null ? $"{c.Teacher.FirstName} {c.Teacher.LastName}" : null,
        SubjectId    = c.SubjectId,
        SubjectName  = c.Subject?.SubjectName ?? "Unknown Subject",
        IsActive     = c.IsActive,
        CreatedAt    = c.CreatedAt,
        // The roster: students currently in the class (dropped and completed enrolments are history).
        Students     = c.StudentClassrooms
            .Where(sc => sc.Status == StudentClassroomStatus.Active && sc.Student != null && sc.Student.DeletedAt == null)
            .Select(sc => new ClassroomStudentDto
            {
                StudentId    = sc.StudentId,
                FirstName    = sc.Student?.FirstName ?? "Unknown",
                LastName     = sc.Student?.LastName ?? "Student",
                Email        = sc.Student?.Email,
                Phone        = sc.Student?.Phone,
                Gender       = sc.Student?.Gender,
                DateOfBirth  = sc.Student?.DateOfBirth,
                EnrolledAt   = sc.EnrolledAt,
                Status       = sc.Status.ToString(),
                UnenrolledAt = sc.UnenrolledAt
            })
            .ToList()
    };
}
