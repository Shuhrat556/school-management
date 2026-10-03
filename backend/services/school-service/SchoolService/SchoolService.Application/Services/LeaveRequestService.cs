using SchoolService.Application.DTOs.LeaveRequests;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class LeaveRequestService : ILeaveRequestService
{
    private readonly ILeaveRequestRepository _requests;
    private readonly IStudentRepository _students;
    private readonly INotificationService _notifications;
    private readonly ICurrentActor _actor;

    public LeaveRequestService(ILeaveRequestRepository requests, IStudentRepository students,
        INotificationService notifications, ICurrentActor actor)
    {
        _requests = requests;
        _students = students;
        _notifications = notifications;
        _actor = actor;
    }

    public async Task<LeaveRequestResponseDto> CreateAsync(Guid studentId, Guid requestedByAuthUserId, LeaveRequestCreateDto dto)
    {
        var student = await _students.GetByIdAsync(studentId);
        if (student == null) throw new NotFoundException("Student", studentId);

        var end = dto.EndDate ?? dto.StartDate;
        if (end < dto.StartDate) throw new ValidationException("The leave cannot end before it starts.");

        var request = new LeaveRequest(studentId, (LeaveType)dto.Type, dto.StartDate, end, dto.Reason, requestedByAuthUserId);
        await _requests.AddAsync(request);
        return MapToResponse(request, $"{student.FirstName} {student.LastName}");
    }

    public async Task<IReadOnlyList<LeaveRequestResponseDto>> GetForStudentsAsync(IReadOnlyCollection<Guid> studentIds)
        => studentIds.Count == 0
            ? []
            : (await _requests.FindAsync(studentIds, null)).Select(r => MapToResponse(r)).ToList();

    public async Task<IReadOnlyList<LeaveRequestResponseDto>> GetAllAsync(LeaveRequestStatus? status, Guid? studentId)
        => (await _requests.FindAsync(studentId.HasValue ? [studentId.Value] : null, status))
            .Select(r => MapToResponse(r)).ToList();

    public async Task<LeaveRequestResponseDto> DecideAsync(Guid id, bool approve, string? note)
    {
        var request = await _requests.GetByIdAsync(id);
        if (request == null) throw new NotFoundException("Leave request", id);
        if (request.Status != LeaveRequestStatus.Pending)
            throw new DuplicateException($"This leave request was already {request.Status.ToString().ToLowerInvariant()}.");

        if (approve) request.Approve(_actor.AuthUserId, _actor.Name, note);
        else request.Reject(_actor.AuthUserId, _actor.Name, note);
        await _requests.UpdateAsync(request);

        var verdict = approve ? "approved" : "rejected";
        var dates = request.StartDate == request.EndDate
            ? $"{request.StartDate:yyyy-MM-dd}"
            : $"{request.StartDate:yyyy-MM-dd} – {request.EndDate:yyyy-MM-dd}";
        await _notifications.NotifyStudentAsync(request.StudentId, NotificationType.LeaveRequest,
            $"Leave request {verdict}", request.ReviewNote == null ? dates : $"{dates}: {request.ReviewNote}");

        return MapToResponse(request);
    }

    private static LeaveRequestResponseDto MapToResponse(LeaveRequest r, string? studentName = null) => new()
    {
        Id             = r.Id,
        StudentId      = r.StudentId,
        StudentName    = studentName ?? (r.Student != null ? $"{r.Student.FirstName} {r.Student.LastName}" : ""),
        Type           = r.Type.ToString(),
        StartDate      = r.StartDate,
        EndDate        = r.EndDate,
        Reason         = r.Reason,
        Status         = r.Status.ToString(),
        CreatedAt      = r.CreatedAt,
        ReviewedByName = r.ReviewedByName,
        ReviewedAt     = r.ReviewedAt,
        ReviewNote     = r.ReviewNote
    };
}
