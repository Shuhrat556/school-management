using SchoolService.Application.DTOs.LeaveRequests;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface ILeaveRequestService
{
    Task<LeaveRequestResponseDto> CreateAsync(Guid studentId, Guid requestedByAuthUserId, LeaveRequestCreateDto dto);
    // A family's requests (the student's own, or a parent's children)
    Task<IReadOnlyList<LeaveRequestResponseDto>> GetForStudentsAsync(IReadOnlyCollection<Guid> studentIds);
    // Staff queue
    Task<IReadOnlyList<LeaveRequestResponseDto>> GetAllAsync(LeaveRequestStatus? status, Guid? studentId);
    Task<LeaveRequestResponseDto> DecideAsync(Guid id, bool approve, string? note);
}
