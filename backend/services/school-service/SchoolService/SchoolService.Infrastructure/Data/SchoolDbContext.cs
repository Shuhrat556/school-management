using Microsoft.EntityFrameworkCore;
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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all configuration classes from the same assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(SchoolDbContext).Assembly);
    }
}
