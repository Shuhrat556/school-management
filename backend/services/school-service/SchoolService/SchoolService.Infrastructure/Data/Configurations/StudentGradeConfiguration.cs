using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class StudentGradeConfiguration : IEntityTypeConfiguration<StudentGrade>
{
    public void Configure(EntityTypeBuilder<StudentGrade> builder)
    {
        builder.HasKey(g => g.Id);

        builder.Property(g => g.Score)
            .HasPrecision(5, 2);

        builder.Property(g => g.Semester)
            .IsRequired()
            .HasMaxLength(20);

        // A student has one final score per subject and semester
        builder.HasIndex(g => new { g.StudentId, g.SubjectId, g.Semester }).IsUnique();

        builder.Property(g => g.GradingMethod)
            .HasConversion<int>();

        // One-to-many with Student
        builder.HasOne(g => g.Student)
            .WithMany(s => s.Grades)
            .HasForeignKey(g => g.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-many with Subject
        builder.HasOne(g => g.Subject)
            .WithMany(s => s.Grades)
            .HasForeignKey(g => g.SubjectId)
            .OnDelete(DeleteBehavior.Restrict);

        // One-to-many with Classroom (optional)
        builder.HasOne(g => g.Classroom)
            .WithMany()
            .HasForeignKey(g => g.ClassroomId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
