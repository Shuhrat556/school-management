namespace SchoolService.Domain.Entities;

public enum LeaveType
{
    Sick     = 1,
    Personal = 2,
    Other    = 3
}

public enum LeaveRequestStatus
{
    Pending  = 1,
    Approved = 2,
    Rejected = 3
}

// A request to excuse a student from classes for one or more days, filed by the student
// or a linked parent and decided once by staff.
public class LeaveRequest
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid StudentId { get; private set; }
    public LeaveType Type { get; private set; }
    public DateOnly StartDate { get; private set; }
    public DateOnly EndDate { get; private set; }
    public string Reason { get; private set; } = null!;
    public LeaveRequestStatus Status { get; private set; } = LeaveRequestStatus.Pending;
    public Guid RequestedByAuthUserId { get; private set; }
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;
    public Guid? ReviewedByAuthUserId { get; private set; }
    public string? ReviewedByName { get; private set; }
    public DateTime? ReviewedAt { get; private set; }
    public string? ReviewNote { get; private set; }

    public Student Student { get; private set; } = null!;

    private LeaveRequest() { } // EF

    public LeaveRequest(Guid studentId, LeaveType type, DateOnly startDate, DateOnly endDate, string reason, Guid requestedByAuthUserId)
    {
        if (endDate < startDate) throw new ArgumentException("The leave cannot end before it starts.");
        StudentId             = studentId;
        Type                  = type;
        StartDate             = startDate;
        EndDate               = endDate;
        Reason                = reason.Trim();
        RequestedByAuthUserId = requestedByAuthUserId;
    }

    public void Approve(Guid? reviewerAuthUserId, string? reviewerName, string? note)
        => Decide(LeaveRequestStatus.Approved, reviewerAuthUserId, reviewerName, note);

    public void Reject(Guid? reviewerAuthUserId, string? reviewerName, string? note)
        => Decide(LeaveRequestStatus.Rejected, reviewerAuthUserId, reviewerName, note);

    private void Decide(LeaveRequestStatus status, Guid? reviewerAuthUserId, string? reviewerName, string? note)
    {
        if (Status != LeaveRequestStatus.Pending)
            throw new InvalidOperationException($"The request was already {Status.ToString().ToLowerInvariant()}.");
        Status               = status;
        ReviewedByAuthUserId = reviewerAuthUserId;
        ReviewedByName       = reviewerName;
        ReviewedAt           = DateTime.UtcNow;
        ReviewNote           = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
    }
}
