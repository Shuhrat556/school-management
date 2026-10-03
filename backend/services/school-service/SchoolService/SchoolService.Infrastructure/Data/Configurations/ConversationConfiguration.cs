using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SchoolService.Domain.Entities;

namespace SchoolService.Infrastructure.Data.Configurations;

public class ConversationConfiguration : IEntityTypeConfiguration<Conversation>
{
    public void Configure(EntityTypeBuilder<Conversation> builder)
    {
        builder.HasKey(c => c.Id);

        builder.Property(c => c.TeacherName).IsRequired().HasMaxLength(200);
        builder.Property(c => c.StudentName).IsRequired().HasMaxLength(200);
        builder.Property(c => c.ParentName).HasMaxLength(200);

        builder.HasOne<Teacher>().WithMany().HasForeignKey(c => c.TeacherId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Student>().WithMany().HasForeignKey(c => c.StudentId).OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(c => c.Messages)
            .WithOne()
            .HasForeignKey(m => m.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(c => c.Messages).UsePropertyAccessMode(PropertyAccessMode.Field);

        // One conversation per teacher, student and parent (or the student themself)
        builder.HasIndex(c => new { c.TeacherId, c.StudentId, c.ParentAuthUserId })
            .IsUnique()
            .AreNullsDistinct(false); // PostgreSQL 15+: only one conversation with the student themself
        builder.HasIndex(c => c.ParentAuthUserId);
    }
}

public class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.HasKey(m => m.Id);
        builder.Property(m => m.SenderRole).HasConversion<int>();
        builder.Property(m => m.SenderName).IsRequired().HasMaxLength(200);
        builder.Property(m => m.Body).IsRequired().HasMaxLength(2000);
        builder.HasIndex(m => new { m.ConversationId, m.SentAt });
    }
}
