using AuthService.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthService.Infrastructure.Data.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        // Primary Key (from BaseEntity)
        builder.HasKey(u => u.Id);

        // Required properties
        builder.Property(u => u.Email)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(u => u.NormalizedEmail)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(u => u.Username)
            .IsRequired()
            .HasMaxLength(101); // "First Last": up to 50 + 1 + 50

        builder.Property(u => u.PasswordHash)
            .IsRequired(false)
            .HasMaxLength(255);

        // Enum stored as string
        builder.Property(u => u.Role)
            .HasConversion<string>()
            .IsRequired();

        builder.Property(u => u.IsEmailVerified)
            .HasDefaultValue(false);

        builder.Property(u => u.IsActive)
            .HasDefaultValue(true);

        builder.Property(u => u.LastLoginAt)
            .IsRequired(false);

        builder.Property(u => u.EmailVerificationCodeHash)
            .HasMaxLength(128)
            .IsRequired(false);

        builder.Property(u => u.EmailVerificationCodeExpiresAt)
            .IsRequired(false);

        builder.Property(u => u.EmailVerificationCodeSentAt)
            .IsRequired(false);

        builder.Property(u => u.EmailVerificationFailedAttempts)
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(u => u.EmailVerificationLockoutUntil)
            .IsRequired(false);

        builder.Property(u => u.PasswordResetCodeHash)
            .HasMaxLength(128)
            .IsRequired(false);

        builder.Property(u => u.PasswordResetCodeExpiresAt)
            .IsRequired(false);

        builder.Property(u => u.PasswordResetCodeSentAt)
            .IsRequired(false);

        builder.Property(u => u.PasswordResetFailedAttempts)
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(u => u.PasswordResetLockoutUntil)
            .IsRequired(false);

        builder.Property(u => u.FailedLoginAttempts)
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(u => u.LoginLockoutUntil)
            .IsRequired(false);

        // Unique index
        builder.HasIndex(u => u.NormalizedEmail)
            .IsUnique();

        // RefreshToken relationship (Aggregate boundary)
        builder.Metadata
            .FindNavigation(nameof(User.RefreshTokens))!
            .SetPropertyAccessMode(PropertyAccessMode.Field);

        builder.HasMany<RefreshToken>()
            .WithOne()
            .HasForeignKey(rt => rt.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Metadata
            .FindNavigation(nameof(User.ExternalLogins))!
            .SetPropertyAccessMode(PropertyAccessMode.Field);

        builder.HasMany<ExternalLogin>()
            .WithOne()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // 🗑 Soft delete filter (optional but recommended)
        //builder.HasQueryFilter(u => !u.IsDeleted);
    }
}