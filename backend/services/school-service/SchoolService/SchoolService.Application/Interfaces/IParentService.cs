using SchoolService.Application.DTOs.Parents;
using SchoolService.Application.DTOs.Students;

namespace SchoolService.Application.Interfaces;

public interface IParentService
{
    Task<IReadOnlyList<StudentParentResponseDto>> GetParentsAsync(Guid studentId);
    // Linking the same parent again updates the stored name, email and relationship.
    Task<StudentParentResponseDto> LinkAsync(Guid studentId, StudentParentCreateDto dto);
    Task UnlinkAsync(Guid studentId, Guid parentAuthUserId);
    Task<IReadOnlyList<StudentResponseDto>> GetChildrenAsync(Guid parentAuthUserId);
    Task<bool> IsParentOfAsync(Guid parentAuthUserId, Guid studentId);
}
