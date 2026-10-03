using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data;

public class SchoolDbContext : DbContext
{
    public SchoolDbContext(DbContextOptions<SchoolDbContext> options) : base(options) { }

    public DbSet<Student>           Students           => Set<Student>();
    public DbSet<Teacher>           Teachers           => Set<Teacher>();
    public DbSet<Department>        Departments        => Set<Department>();
    public DbSet<TeacherDepartment> TeacherDepartments => Set<TeacherDepartment>();
    public DbSet<Classroom>         Classrooms         => Set<Classroom>();
    public DbSet<StudentClassroom>  StudentClassrooms  => Set<StudentClassroom>();
    public DbSet<Subject>           Subjects           => Set<Subject>();
    public DbSet<TeacherSubject>    TeacherSubjects    => Set<TeacherSubject>();
    public DbSet<StudentGrade>      StudentGrades      => Set<StudentGrade>();
    public DbSet<Attendance>        Attendances        => Set<Attendance>();
    public DbSet<Schedule>          Schedules          => Set<Schedule>();
    public DbSet<Room>              Rooms              => Set<Room>();
    public DbSet<Material>          Materials          => Set<Material>();
    public DbSet<Submission>        Submissions        => Set<Submission>();
    public DbSet<Announcement>      Announcements      => Set<Announcement>();
    public DbSet<StudentParent>     StudentParents     => Set<StudentParent>();
    public DbSet<Notification>      Notifications      => Set<Notification>();
    public DbSet<GradeChange>       GradeChanges       => Set<GradeChange>();
    public DbSet<LeaveRequest>      LeaveRequests      => Set<LeaveRequest>();
    public DbSet<Conversation>      Conversations      => Set<Conversation>();
    public DbSet<Message>           Messages           => Set<Message>();

    // Npgsql writes only UTC to "timestamp with time zone" (every DateTime column here).
    // A time without a zone, e.g. a birth date posted as "2006-05-05", is taken as UTC
    // like the rest of the API, instead of failing the save with a 500 (BUGS B50).
    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all configuration classes from the same assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(SchoolDbContext).Assembly);
    }
}

internal sealed class UtcDateTimeConverter() : ValueConverter<DateTime, DateTime>(
    value => value.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(value, DateTimeKind.Utc) : value.ToUniversalTime(),
    value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
