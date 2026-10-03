using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class GradeChangeConfiguration : IEntityTypeConfiguration<GradeChange>
{
    public void Configure(EntityTypeBuilder<GradeChange> builder)
    {
        builder.HasKey(c => c.Id);

        builder.Property(c => c.Action)
            .HasConversion<int>();

        builder.Property(c => c.Semester)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(c => c.OldScore)
            .HasPrecision(5, 2);

        builder.Property(c => c.NewScore)
            .HasPrecision(5, 2);

        builder.Property(c => c.ChangedByName)
            .HasMaxLength(200);

        builder.Property(c => c.ChangedByRole)
            .HasMaxLength(20);

        builder.HasIndex(c => c.GradeId);
        builder.HasIndex(c => new { c.StudentId, c.ChangedAt });
    }
}
