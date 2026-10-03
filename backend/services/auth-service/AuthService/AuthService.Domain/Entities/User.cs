using AuthService.Domain.Entities.Common;
using AuthService.Domain.Enums;

namespace AuthService.Domain.Entities;

public class User : BaseEntity
{
    
    private readonly List<ExternalLogin> _externalLogins = new();
    public IReadOnlyCollection<ExternalLogin> ExternalLogins => _externalLogins;
    public ExternalLogin AddExternalLogin(ExternalAuthProvider provider, string providerUserId)
    {
        var externalLogin = new ExternalLogin(Id, provider, providerUserId);
        _externalLogins.Add(externalLogin);
        return externalLogin;
    }

    public void RemoveExternalLogin(ExternalLogin externalLogin) => _externalLogins.Remove(externalLogin);

    public string Email { get; private set; } = string.Empty;
    public string NormalizedEmail { get; private set; } = string.Empty;
    public string Username { get; private set; } = string.Empty;
    public string? PasswordHash { get; private set; } = string.Empty;
    
    public UserRole Role { get; private set; }
    public bool IsEmailVerified { get; private set; }
    public bool IsActive { get; private set; }

    public string? EmailVerificationCodeHash { get; private set; }
    public DateTime? EmailVerificationCodeExpiresAt { get; private set; }
    public DateTime? EmailVerificationCodeSentAt { get; private set; }
    public int EmailVerificationFailedAttempts { get; private set; }
    public DateTime? EmailVerificationLockoutUntil { get; private set; }

    public string? PasswordResetCodeHash { get; private set; }
    public DateTime? PasswordResetCodeExpiresAt { get; private set; }
    public DateTime? PasswordResetCodeSentAt { get; private set; }
    public int PasswordResetFailedAttempts { get; private set; }
    public DateTime? PasswordResetLockoutUntil { get; private set; }

    public int FailedLoginAttempts { get; private set; }
    public DateTime? LoginLockoutUntil { get; private set; }

    public DateTime? LastLoginAt { get; private set; }

    private readonly List<RefreshToken> _refreshTokens = new();
    public IReadOnlyCollection<RefreshToken> RefreshTokens => _refreshTokens;

    protected User() { } // EF

    public User(string email, string username, UserRole role)
    {
        Id = Guid.NewGuid();
        Email = email;
        NormalizedEmail = email.ToUpperInvariant();
        Username = username;
        Role = role;
        IsActive = true;
    }

    public void VerifyEmail()
        => IsEmailVerified = true;

    public void SetEmailVerificationCode(string codeHash, DateTime expiresAt, DateTime sentAt)
    {
        EmailVerificationCodeHash = codeHash;
        EmailVerificationCodeExpiresAt = expiresAt;
        EmailVerificationCodeSentAt = sentAt;
        EmailVerificationFailedAttempts = 0;
        EmailVerificationLockoutUntil = null;
    }

    public void ClearEmailVerificationCode()
    {
        EmailVerificationCodeHash = null;
        EmailVerificationCodeExpiresAt = null;
        EmailVerificationCodeSentAt = null;
        EmailVerificationFailedAttempts = 0;
        EmailVerificationLockoutUntil = null;
    }

    public void SetPasswordResetCode(string codeHash, DateTime expiresAt, DateTime sentAt)
    {
        PasswordResetCodeHash = codeHash;
        PasswordResetCodeExpiresAt = expiresAt;
        PasswordResetCodeSentAt = sentAt;
        PasswordResetFailedAttempts = 0;
        PasswordResetLockoutUntil = null;
    }

    public void ClearPasswordResetCode()
    {
        PasswordResetCodeHash = null;
        PasswordResetCodeExpiresAt = null;
        PasswordResetCodeSentAt = null;
        PasswordResetFailedAttempts = 0;
        PasswordResetLockoutUntil = null;
    }

    public void RecordFailedPasswordResetAttempt(int maxAttempts, TimeSpan lockoutDuration)
    {
        PasswordResetFailedAttempts++;
        if (PasswordResetFailedAttempts >= maxAttempts)
            PasswordResetLockoutUntil = DateTime.UtcNow.Add(lockoutDuration);
    }

    public void RecordFailedEmailVerificationAttempt(int maxAttempts, TimeSpan lockoutDuration)
    {
        EmailVerificationFailedAttempts++;
        if (EmailVerificationFailedAttempts >= maxAttempts)
            EmailVerificationLockoutUntil = DateTime.UtcNow.Add(lockoutDuration);
    }

    public void RecordLogin()
    {
        LastLoginAt = DateTime.UtcNow;
        FailedLoginAttempts = 0;
        LoginLockoutUntil = null;
    }

    public bool IsLoginLockedOut(DateTime now)
        => LoginLockoutUntil.HasValue && LoginLockoutUntil.Value > now;

    // After maxAttempts wrong passwords in a row the account is locked for
    // lockoutDuration; the counter restarts so the next lockout needs another run.
    public void RecordFailedLogin(int maxAttempts, TimeSpan lockoutDuration)
    {
        FailedLoginAttempts++;
        if (FailedLoginAttempts >= maxAttempts)
        {
            LoginLockoutUntil = DateTime.UtcNow.Add(lockoutDuration);
            FailedLoginAttempts = 0;
        }
    }

    public void ChangeRole(UserRole newRole)
        => Role = newRole;
    
    public void SetPasswordHash(string hash) => PasswordHash = hash;
    
    public RefreshToken AddRefreshToken(string token, DateTime expiresAt)
    {
        // Expired tokens can no longer be used or replayed, so they are not kept.
        _refreshTokens.RemoveAll(t => t.IsExpired);
        var refreshToken = new RefreshToken(Id, token, expiresAt);
        _refreshTokens.Add(refreshToken);
        return refreshToken;
    }

    // Ends every session (password change or reset, refresh token reuse).
    public void RevokeAllRefreshTokens()
    {
        foreach (var refreshToken in _refreshTokens.Where(t => t.IsActive))
            refreshToken.Revoke();
    }
}