using AuthService.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthService.Infrastructure.Data.Configurations;

public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        // Primary Key
        builder.HasKey(rt => rt.Id);

        // Required fields
        // Holds the SHA-256 of the token, never the token itself
        builder.Property(rt => rt.Token)
            .IsRequired()
            .HasMaxLength(500);

        builder.HasIndex(rt => rt.Token);

        builder.Property(rt => rt.ExpiresAt)
            .IsRequired();

        // Foreign key to User aggregate
        builder.HasOne<User>()
            .WithMany("RefreshTokens") // Use string because EF will resolve private field
            .HasForeignKey(rt => rt.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Optional: soft delete query filter
        builder.HasQueryFilter(rt => !rt.IsDeleted);
    }
}