using AuthService.Application.DTOs.Auth.Request;
using AuthService.Application.DTOs.User;
using AuthService.Application.Interfaces;
using AuthService.Domain.Enums;
using AuthService.Infrastructure.Settings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace AuthService.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthenticationService _authService;
    private readonly IUserRepository _userRepository;
    private readonly IConfiguration _configuration;
    
    public AuthController(IAuthenticationService authService, IUserRepository userRepository, IConfiguration configuration)
    {
        _authService = authService;
        _userRepository = userRepository;
        _configuration = configuration;
    }
    
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] UserCreateDto dto)
    {
        try
        { 
            var result = await _authService.RegisterAsync(dto);
            return Ok(new 
            { 
                success = true,
                message = "Registration successful. Please verify your email to complete the process.",
                user = result,
                nextStep = "POST /api/auth/verify-email",
                verificationFlow = new
                {
                    step1 = "POST /api/auth/request-email-verification-code (to get code sent to email)",
                    step2 = "POST /api/auth/verify-email (with email and code to mark as verified)",
                    step3 = "POST /api/auth/authenticate (to login after verification)"
                }
            });
        }
        catch (Exception ex)
        {
            return BadRequest(new 
            { 
                success = false,
                error = ex.Message,
                code = "REGISTRATION_FAILED"
            });
        }
    }

    [HttpPost("authenticate")]
    public async Task<IActionResult> Authenticate([FromBody] LoginRequestDto dto)
    {
        var result = await _authService.AuthenticateAsync(dto.Email, dto.Password);
        if (result != null)
            return Ok(result);

        // Authentication failed - check if it's due to unverified email
        var user = await _userRepository.GetByEmailAsync(dto.Email.Trim().ToUpperInvariant());
        if (user != null && !user.IsEmailVerified)
        {
            return Unauthorized(new 
            { 
                error = "Email not verified",
                message = "Please verify your email before logging in",
                code = "EMAIL_NOT_VERIFIED",
                //nextStep = "POST /api/auth/request-email-verification-code"
            });
        }

        // Generic error for wrong password or user not found
        return Unauthorized(new 
        { 
            error = "Invalid email or password",
            code = "INVALID_CREDENTIALS"
        });
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshTokenRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.RefreshToken))
            return BadRequest(new { success = false, message = "Refresh token is required" });

        var result = await _authService.RefreshTokenAsync(dto.RefreshToken);
        
        if (result == null)
            return Unauthorized(new { success = false, message = "Invalid or expired refresh token" });
        
        return Ok(result);
    }

    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutRequestDto dto)
    {
        var loggedOut = await _authService.LogoutAsync(dto.RefreshToken);
        return Ok(loggedOut);
    }

    [HttpPost("request-email-verification-code")]
    public async Task<IActionResult> RequestEmailVerificationCode([FromBody] RequestEmailVerificationCodeRequestDto dto)
    {
        await _authService.RequestEmailVerificationCodeAsync(dto.Email);
        return Ok(new 
        { 
            success = true,
            message = "Verification code sent to your email",
            email = dto.Email,
            nextStep = "POST /api/auth/verify-email",
            instructions = "Check your inbox for the verification code and submit it along with your email"
        });
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequestDto dto)
    {
        var verified = await _authService.VerifyEmailAsync(dto.Email, dto.Code);
        if (!verified)
        {
            return BadRequest(new 
            { 
                error = "Email verification failed",
                message = "Invalid verification code or email",
                code = "VERIFICATION_FAILED"
            });
        }
        
        return Ok(new 
        { 
            success = true,
            message = "Email verified successfully",
            email = dto.Email,
            nextStep = "POST /api/auth/authenticate",
            instructions = "You can now login with your email and password"
        });
    }

    [HttpPost("request-password-reset")]
    public async Task<IActionResult> RequestPasswordReset([FromBody] RequestPasswordResetRequestDto dto)
    {
        await _authService.RequestPasswordResetAsync(dto.Email);
        return Ok();
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto dto)
    {
        var reset = await _authService.ResetPasswordAsync(dto.Email, dto.Code, dto.NewPassword);
        return Ok(reset);
    }

    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequestDto dto)
    {
        // Only the account owner may change their own password
        var callerId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        if (!Guid.TryParse(callerId, out var callerGuid) || callerGuid != dto.UserId)
            return Forbid();

        var changed = await _authService.ChangePasswordAsync(dto.UserId, dto.CurrentPassword, dto.NewPassword);
        if (!changed)
            return BadRequest(new { success = false, error = "Current password is incorrect or the account is unavailable." });

        return Ok(new { success = true, message = "Password changed successfully." });
    }

    [HttpPost("oauth/google")]
public async Task<IActionResult> OAuthGoogle([FromBody] GoogleAuthRequestDto dto)
{
    var result = await _authService.AuthenticateGoogleAsync(dto.IdToken);
    return result == null ? Unauthorized() : Ok(result);
}

[HttpPost("oauth/facebook")]
public async Task<IActionResult> OAuthFacebook([FromBody] FacebookAuthRequestDto dto)
{
    var result = await _authService.AuthenticateFacebookAsync(dto.AccessToken);
    return result == null ? Unauthorized() : Ok(result);
}

// Validates a JWT token (signature, issuer, audience, expiry) - mainly called by other services like school-service
[HttpPost("validate")]
public IActionResult ValidateToken([FromBody] ValidateTokenRequest request)
{
    if (string.IsNullOrEmpty(request?.Token))
        return BadRequest(new { valid = false, error = "Token is required" });

    try
    {
        var handler = new JwtSecurityTokenHandler { MapInboundClaims = false };
        var principal = handler.ValidateToken(request.Token, JwtConfig.CreateValidationParameters(_configuration), out _);

        return Ok(new
        {
            valid = true,
            userId = principal.FindFirstValue(JwtRegisteredClaimNames.Sub),
            email = principal.FindFirstValue(JwtRegisteredClaimNames.Email)
        });
    }
    catch (SecurityTokenExpiredException)
    {
        return Ok(new { valid = false, error = "Token has expired" });
    }
    catch (Exception ex) when (ex is SecurityTokenException or ArgumentException)
    {
        return Ok(new { valid = false, error = "Invalid token" });
    }
}

// Returns user info for a given ID - other microservices call this to look up users
[Authorize]
[HttpGet("user/{userId}")]
public async Task<IActionResult> GetUser(string userId)
{
    if (string.IsNullOrEmpty(userId))
        return BadRequest(new { error = "UserId is required" });

    try
    {
        var user = await _userRepository.GetByIdAsync(Guid.Parse(userId));
        
        if (user == null)
            return NotFound(new { error = "User not found" });

        return Ok(new
        {
            userId = user.Id,
            username = user.Username,
            email = user.Email,
            fullName = user.Username,
            role = user.Role,
            isActive = user.IsActive,
            isEmailVerified = user.IsEmailVerified,
            createdAt = user.CreatedAt
        });
    }
    catch (Exception ex)
    {
        return BadRequest(new { error = ex.Message });
    }
}
// ── Admin endpoints (internal use by admin-web) ──────────────────────────────

    // List all users in auth_db
    [Authorize(Roles = "Admin")]
    [HttpGet("admin/users")]
    public async Task<IActionResult> AdminGetUsers()
    {
        var users = await _authService.GetAllUsersAsync();
        return Ok(users);
    }

    // Create a user account with a specific role
    [Authorize(Roles = "Admin")]
    [HttpPost("admin/users")]
    public async Task<IActionResult> AdminCreateUser([FromBody] AdminCreateUserDto dto)
    {
        try
        {
            var user = await _authService.AdminCreateUserAsync(dto);
            return Ok(new { success = true, user });
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, error = ex.Message });
        }
    }

    // Delete a user account from auth_db
    [Authorize(Roles = "Admin")]
    [HttpDelete("admin/users/{userId:guid}")]
    public async Task<IActionResult> AdminDeleteUser(Guid userId)
    {
        try
        {
            await _authService.DeleteUserAsync(userId);
            return NoContent();
        }
        catch (Exception ex)
        {
            return NotFound(new { success = false, error = ex.Message });
        }
    }

    // Update a user's role in auth_db
    [Authorize(Roles = "Admin")]
    [HttpPatch("admin/users/{userId:guid}/role")]
    public async Task<IActionResult> AdminUpdateUserRole(Guid userId, [FromBody] UpdateUserRoleDto dto)
    {
        try
        {
            await _authService.UpdateUserRoleAsync(userId, dto.Role);
            return NoContent();
        }
        catch (Exception ex)
        {
            return NotFound(new { success = false, error = ex.Message });
        }
    }
}

public class ValidateTokenRequest
{
    public string? Token { get; set; }
}
