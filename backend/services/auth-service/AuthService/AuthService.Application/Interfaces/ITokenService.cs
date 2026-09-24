using AuthService.Domain.Entities;

namespace AuthService.Application.Interfaces;

public interface ITokenService
{
    /// Generates a JWT access token for the user.
    string GenerateAccessToken(User user);
    
    /// Generates a refresh token.
    string GenerateRefreshToken();
    
    /// Gets the expiration time for refresh tokens.
    DateTime GetRefreshTokenExpiration();

    /// The form a refresh token is stored and looked up in (clients get the raw token).
    string HashRefreshToken(string refreshToken);
}
