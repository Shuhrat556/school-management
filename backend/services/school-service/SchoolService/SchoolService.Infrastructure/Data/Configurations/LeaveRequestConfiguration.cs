using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class LeaveRequestConfiguration : IEntityTypeConfiguration<LeaveRequest>
{
    public void Configure(EntityTypeBuilder<LeaveRequest> builder)
    {
        builder.HasKey(r => r.Id);

        builder.Property(r => r.Type).HasConversion<int>();
        builder.Property(r => r.Status).HasConversion<int>();

        builder.Property(r => r.Reason)
            .IsRequired()
            .HasMaxLength(1000);

        builder.Property(r => r.ReviewedByName).HasMaxLength(200);
        builder.Property(r => r.ReviewNote).HasMaxLength(500);

        builder.HasOne(r => r.Student)
            .WithMany()
            .HasForeignKey(r => r.StudentId)
            .OnDelete(DeleteBehavior.Cascade);

        // A family's history (newest first) and the staff queue of pending requests
        builder.HasIndex(r => new { r.StudentId, r.CreatedAt });
        builder.HasIndex(r => new { r.Status, r.CreatedAt });
    }
}
