using AuthService.Application.DTOs.Auth.Response;
using AuthService.Application.DTOs.User;
using AuthService.Domain.Enums;

namespace AuthService.Application.Interfaces;

public interface IAuthenticationService
{ 
    Task<UserResponseDto> RegisterAsync(UserCreateDto dto);
    Task<AuthResponseDto?> AuthenticateAsync(string email, string password);
    Task RequestEmailVerificationCodeAsync(string email);
    Task<bool> VerifyEmailAsync(string email, string code);
    Task<AuthResponseDto?> RefreshTokenAsync(string refreshToken);
    Task<bool> LogoutAsync(string refreshToken);
    Task RequestPasswordResetAsync(string email);
    Task<bool> ResetPasswordAsync(string email, string code, string newPassword);
    Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword);
    Task<AuthResponseDto?> AuthenticateGoogleAsync(string idToken);
    Task<AuthResponseDto?> AuthenticateFacebookAsync(string accessToken);
    Task<UserResponseDto> AdminCreateUserAsync(AdminCreateUserDto dto);
    Task<IEnumerable<UserResponseDto>> GetAllUsersAsync();
    Task DeleteUserAsync(Guid userId);
    Task UpdateUserRoleAsync(Guid userId, Domain.Enums.UserRole newRole);
    // Account linking (F6): the signed-in user's Google/Facebook logins.
    Task<ExternalLoginsResponseDto> GetExternalLoginsAsync(Guid userId);
    Task<ExternalLoginsResponseDto> LinkExternalLoginAsync(Guid userId, ExternalAuthProvider provider, string token);
    Task UnlinkExternalLoginAsync(Guid userId, ExternalAuthProvider provider);
}

