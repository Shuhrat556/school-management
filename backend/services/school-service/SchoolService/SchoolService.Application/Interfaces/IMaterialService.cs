using SchoolService.Application.DTOs.Materials;

namespace SchoolService.Application.Interfaces;

public interface IMaterialService
{
    // Deleted materials never; inactive ones only when includeInactive (staff).
    Task<List<MaterialResponseDto>> GetMaterialsByClassroomAsync(Guid classroomId, bool includeInactive);
    Task<MaterialResponseDto> CreateMaterialAsync(MaterialCreateDto dto);
    Task<bool> UpdateMaterialAsync(Guid id, MaterialUpdateDto dto);
    Task<bool> DeleteMaterialAsync(Guid id);
}
