using SchoolService.Application.DTOs.Submissions;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class SubmissionService : ISubmissionService
{
    private readonly ISubmissionRepository _submissionRepository;
    private readonly IMaterialRepository _materialRepository;
    private readonly IClassroomRepository _classroomRepository;

    public SubmissionService(ISubmissionRepository submissionRepository, IMaterialRepository materialRepository,
        IClassroomRepository classroomRepository)
    {
        _submissionRepository = submissionRepository;
        _materialRepository = materialRepository;
        _classroomRepository = classroomRepository;
    }

    public async Task<SubmissionResponseDto> SubmitAsync(Guid studentId, SubmissionCreateDto dto)
    {
        var material = await _materialRepository.GetByIdAsync(dto.MaterialId);
        if (material == null || !material.IsActive || material.IsDeleted)
            throw new NotFoundException("Material", dto.MaterialId);

        // Only students in the class hand in its work; to anyone else the material does not exist.
        var enrollment = await _classroomRepository.GetEnrollmentAsync(material.ClassroomId, studentId);
        if (enrollment?.Status != StudentClassroomStatus.Active)
            throw new NotFoundException("Material", dto.MaterialId);

        var submission = new Submission(dto.MaterialId, studentId, dto.SubmissionUrl);
        await _submissionRepository.AddAsync(submission);

        return await GetSubmissionResponseAsync(submission.Id);
    }

    public async Task<bool> GradeSubmissionAsync(Guid submissionId, GradeSubmissionDto dto)
    {
        var submission = await _submissionRepository.GetByIdAsync(submissionId);
        if (submission == null) return false;

        submission.UpdateGrade(dto.Grade, dto.Feedback);
        await _submissionRepository.UpdateAsync(submission);
        return true;
    }

    public async Task<List<SubmissionResponseDto>> GetSubmissionsByMaterialAsync(Guid materialId)
    {
        var submissions = await _submissionRepository.GetByMaterialAsync(materialId);
        return submissions
            .Select(MapToResponse)
            .ToList();
    }

    public async Task<List<SubmissionResponseDto>> GetSubmissionsByStudentAsync(Guid studentId)
    {
        var submissions = await _submissionRepository.GetByStudentAsync(studentId);
        return submissions
            .Select(MapToResponse)
            .ToList();
    }

    private async Task<SubmissionResponseDto> GetSubmissionResponseAsync(Guid id)
    {
        var submission = await _submissionRepository.GetByIdWithDetailsAsync(id);
        if (submission == null) throw new Exception("Submission not found after creation.");
        return MapToResponse(submission);
    }

    private static SubmissionResponseDto MapToResponse(Submission s) => new()
    {
        Id = s.Id,
        MaterialId = s.MaterialId,
        MaterialTitle = s.Material?.Title ?? "",
        StudentId = s.StudentId,
        StudentName = s.Student != null ? $"{s.Student.FirstName} {s.Student.LastName}" : "",
        SubmissionUrl = s.SubmissionUrl,
        SubmittedAt = s.SubmittedAt,
        Grade = s.Grade,
        Feedback = s.Feedback
    };
}
