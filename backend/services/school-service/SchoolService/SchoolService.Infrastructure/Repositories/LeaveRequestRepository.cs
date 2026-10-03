using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class LeaveRequestRepository : ILeaveRequestRepository
{
    private readonly SchoolDbContext _context;

    public LeaveRequestRepository(SchoolDbContext context) => _context = context;

    public async Task<LeaveRequest?> GetByIdAsync(Guid id)
        => await _context.LeaveRequests
            .Include(r => r.Student)
            .FirstOrDefaultAsync(r => r.Id == id);

    public async Task<List<LeaveRequest>> FindAsync(IReadOnlyCollection<Guid>? studentIds, LeaveRequestStatus? status)
    {
        var query = _context.LeaveRequests.AsNoTracking().Include(r => r.Student).AsQueryable();
        if (studentIds != null) query = query.Where(r => studentIds.Contains(r.StudentId));
        if (status.HasValue) query = query.Where(r => r.Status == status.Value);
        return await query.OrderByDescending(r => r.CreatedAt).ToListAsync();
    }

    public async Task AddAsync(LeaveRequest request)
    {
        await _context.LeaveRequests.AddAsync(request);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(LeaveRequest request)
    {
        _context.LeaveRequests.Update(request);
        await _context.SaveChangesAsync();
    }
}
