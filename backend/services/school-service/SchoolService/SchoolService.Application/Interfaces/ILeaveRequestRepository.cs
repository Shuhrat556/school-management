using SchoolService.Domain.Entities;

namespace SchoolService.Application.Interfaces;

public interface ILeaveRequestRepository
{
    Task<LeaveRequest?> GetByIdAsync(Guid id);
    // Newest first, with the student; filters are optional
    Task<List<LeaveRequest>> FindAsync(IReadOnlyCollection<Guid>? studentIds, LeaveRequestStatus? status);
    Task AddAsync(LeaveRequest request);
    Task UpdateAsync(LeaveRequest request);
}
