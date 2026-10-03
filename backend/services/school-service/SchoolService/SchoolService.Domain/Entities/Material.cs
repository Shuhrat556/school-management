namespace SchoolService.Domain.Entities;

public enum MaterialType
{
    Slide      = 1,
    Assignment = 2,
    Link       = 3,
    Reference  = 4
}

public class Material
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public Guid ClassroomId { get; private set; }
    public string Title { get; private set; } = null!;
    public string? Description { get; private set; }
    public string? Url { get; private set; }
    public MaterialType Type { get; private set; }
    /// <summary>When an assignment is due (UTC); null when there is no deadline.</summary>
    public DateTime? DueAt { get; private set; }
    public bool IsActive { get; private set; } = true;
    public DateTime CreatedAt { get; private set; } = DateTime.UtcNow;
    public DateTime? DeletedAt { get; private set; }

    public Classroom Classroom { get; private set; } = null!;

    private readonly List<Submission> _submissions = new();
    public IReadOnlyCollection<Submission> Submissions => _submissions;

    private Material() { } // EF

    public Material(Guid classroomId, string title, MaterialType type,
        string? url = null, string? description = null, DateTime? dueAt = null)
    {
        ClassroomId = classroomId;
        UpdateInfo(title, type, url, description, dueAt);
    }

    public void UpdateInfo(string title, MaterialType type, string? url, string? description, DateTime? dueAt = null)
    {
        Title       = title.Trim();
        Type        = type;
        Url         = string.IsNullOrWhiteSpace(url) ? null : url.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        // A time without a zone is taken as UTC, like the rest of the API.
        DueAt = dueAt switch
        {
            null => null,
            { Kind: DateTimeKind.Unspecified } d => DateTime.SpecifyKind(d, DateTimeKind.Utc),
            { } d => d.ToUniversalTime()
        };
    }

    public void Deactivate() => IsActive = false;
    public void Activate()   => IsActive = true;
    public void SoftDelete() => DeletedAt = DateTime.UtcNow;
    public bool IsDeleted    => DeletedAt.HasValue;
}
