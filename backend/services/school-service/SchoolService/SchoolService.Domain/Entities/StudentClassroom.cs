namespace SchoolService.Domain.Entities;

public enum StudentClassroomStatus
{
    Active    = 1,
    Dropped   = 2,
    Completed = 3
}

public class StudentClassroom
{
    public Guid StudentId { get; private set; }
    public Guid ClassroomId { get; private set; }
    public StudentClassroomStatus Status { get; private set; } = StudentClassroomStatus.Active;
    public DateTime EnrolledAt { get; private set; } = DateTime.UtcNow;
    public DateTime? UnenrolledAt { get; private set; }

    public Student Student { get; private set; } = null!;
    public Classroom Classroom { get; private set; } = null!;

    private StudentClassroom() { } // EF

    public StudentClassroom(Guid studentId, Guid classroomId)
    {
        StudentId   = studentId;
        ClassroomId = classroomId;
    }

    public void Drop()
    {
        Status       = StudentClassroomStatus.Dropped;
        UnenrolledAt = DateTime.UtcNow;
    }

    public void Complete()
    {
        Status       = StudentClassroomStatus.Completed;
        UnenrolledAt = DateTime.UtcNow;
    }

    public void Reenroll()
    {
        Status       = StudentClassroomStatus.Active;
        EnrolledAt   = DateTime.UtcNow;
        UnenrolledAt = null;
    }
}
