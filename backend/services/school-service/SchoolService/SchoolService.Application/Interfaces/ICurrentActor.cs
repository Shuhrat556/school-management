namespace SchoolService.Application.Interfaces;

// The signed-in user making the current request (for audit records).
public interface ICurrentActor
{
    Guid? AuthUserId { get; }
    string? Name { get; }
    string? Role { get; }
}
