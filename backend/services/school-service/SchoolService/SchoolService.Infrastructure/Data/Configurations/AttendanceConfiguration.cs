using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class AttendanceConfiguration : IEntityTypeConfiguration<Attendance>
{
    public void Configure(EntityTypeBuilder<Attendance> builder)
    {
        builder.HasKey(a => a.Id);

        builder.Property(a => a.Status)
            .HasConversion<int>();

        // One mark per student, classroom and day (BulkMark updates an existing one)
        builder.HasIndex(a => new { a.StudentId, a.ClassroomId, a.Date }).IsUnique();

        // One-to-many with Student
        builder.HasOne(a => a.Student)
            .WithMany(s => s.Attendances)
            .HasForeignKey(a => a.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-many with Classroom (optional)
        builder.HasOne(a => a.Classroom)
            .WithMany()
            .HasForeignKey(a => a.ClassroomId)
            .OnDelete(DeleteBehavior.SetNull);

        // One-to-many with Schedule (optional)
        builder.HasOne(a => a.Schedule)
            .WithMany()
            .HasForeignKey(a => a.ScheduleId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
