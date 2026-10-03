using SchoolService.Application.DTOs.Materials;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class MaterialService : IMaterialService
{
    private readonly IMaterialRepository _materialRepository;
    private readonly IClassroomRepository _classroomRepository;

    public MaterialService(IMaterialRepository materialRepository, IClassroomRepository classroomRepository)
    {
        _materialRepository = materialRepository;
        _classroomRepository = classroomRepository;
    }

    public async Task<List<MaterialResponseDto>> GetMaterialsByClassroomAsync(Guid classroomId, bool includeInactive)
    {
        var materials = await _materialRepository.GetByClassroomAsync(classroomId);
        return materials
            .Where(m => includeInactive || m.IsActive)
            .Select(MapToResponse)
            .ToList();
    }

    public async Task<MaterialResponseDto> CreateMaterialAsync(MaterialCreateDto dto)
    {
        if (await _classroomRepository.GetByIdAsync(dto.ClassroomId) == null)
            throw new NotFoundException("Classroom", dto.ClassroomId);

        var material = new Material(dto.ClassroomId, dto.Title, dto.Type, dto.Url, dto.Description, dto.DueAt);
        await _materialRepository.AddAsync(material);
        return MapToResponse(material);
    }

    public async Task<bool> UpdateMaterialAsync(Guid id, MaterialUpdateDto dto)
    {
        var material = await _materialRepository.GetByIdAsync(id);
        if (material == null || material.IsDeleted) return false;

        material.UpdateInfo(dto.Title, dto.Type, dto.Url, dto.Description, dto.DueAt);
        if (dto.IsActive) material.Activate(); else material.Deactivate();

        await _materialRepository.UpdateAsync(material);
        return true;
    }

    // Soft delete: students' hand-ins (and their grades) stay (BUGS B35).
    public async Task<bool> DeleteMaterialAsync(Guid id)
    {
        var material = await _materialRepository.GetByIdAsync(id);
        if (material == null || material.IsDeleted) return false;

        material.SoftDelete();
        material.Deactivate();
        await _materialRepository.UpdateAsync(material);
        return true;
    }

    private static MaterialResponseDto MapToResponse(Material m) => new()
    {
        Id = m.Id,
        ClassroomId = m.ClassroomId,
        Title = m.Title,
        Description = m.Description,
        Url = m.Url,
        Type = m.Type,
        // Stored as UTC; say so in the JSON even when the provider drops the kind
        DueAt = m.DueAt is { } due ? DateTime.SpecifyKind(due, DateTimeKind.Utc) : null,
        SubmissionCount = m.Submissions.Select(s => s.StudentId).Distinct().Count(),
        IsActive = m.IsActive,
        CreatedAt = m.CreatedAt
    };
}
