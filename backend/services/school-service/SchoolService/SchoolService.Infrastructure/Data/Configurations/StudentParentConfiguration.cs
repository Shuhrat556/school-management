using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class StudentParentConfiguration : IEntityTypeConfiguration<StudentParent>
{
    public void Configure(EntityTypeBuilder<StudentParent> builder)
    {
        builder.HasKey(sp => sp.Id);

        builder.Property(sp => sp.FullName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(sp => sp.Email)
            .HasMaxLength(200);

        builder.Property(sp => sp.Relationship)
            .HasMaxLength(50);

        builder.HasOne(sp => sp.Student)
            .WithMany()
            .HasForeignKey(sp => sp.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        // A parent is linked to a given child once; lookups go by parent account.
        builder.HasIndex(sp => new { sp.StudentId, sp.ParentAuthUserId }).IsUnique();
        builder.HasIndex(sp => sp.ParentAuthUserId);
    }
}
