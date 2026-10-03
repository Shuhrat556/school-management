using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using AuthService.Application.Exceptions;
using AuthService.Application.Interfaces;
using AuthService.Domain.Enums;
using Google.Apis.Auth;
using Microsoft.Extensions.Configuration;

namespace AuthService.Infrastructure.Services;

public class ExternalAuthValidator : IExternalAuthValidator
{
    private readonly IConfiguration _config;
    private readonly HttpClient _http;

    public ExternalAuthValidator(IConfiguration config, HttpClient http)
    {
        _config = config;
        _http = http;
    }

    public async Task<ExternalAuthIdentity> ValidateGoogleIdTokenAsync(string idToken)
    {
        var googleClientId = _config["Authentication:Google:ClientId"]
            ?? throw new ConfigurationException("Authentication:Google:ClientId not configured");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(idToken, new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = new[] { googleClientId }
            });
        }
        catch (InvalidJwtException)
        {
            throw new ExternalTokenException("Google token is invalid or expired");
        }

        return new ExternalAuthIdentity(
            Provider: ExternalAuthProvider.Google,
            ProviderUserId: payload.Subject,
            Email: payload.Email,
            EmailVerified: payload.EmailVerified == true, // Treat unverified email as invalid
            DisplayName: payload.Name
        );
    }

    public async Task<ExternalAuthIdentity> ValidateFacebookAccessTokenAsync(string accessToken)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
            throw new ArgumentException("Access token is required", nameof(accessToken));

        var appId = _config["Authentication:Facebook:AppId"];
        var appSecret = _config["Authentication:Facebook:AppSecret"];

        if (string.IsNullOrWhiteSpace(appId))
            throw new ConfigurationException("Authentication:Facebook:AppId not configured");

        if (string.IsNullOrWhiteSpace(appSecret))
            throw new ConfigurationException("Authentication:Facebook:AppSecret not configured");

        // 1) Validate token and extract user_id reliably
        // debug_token requires an app access token: {app-id}|{app-secret}
        var appAccessToken = $"{appId}|{appSecret}";
        var debugUrl =
            $"https://graph.facebook.com/debug_token?input_token={Uri.EscapeDataString(accessToken)}&access_token={Uri.EscapeDataString(appAccessToken)}";

        // Facebook answers 400 for a token it cannot parse at all.
        using var debugResponse = await _http.GetAsync(debugUrl);
        if (debugResponse.StatusCode == HttpStatusCode.BadRequest)
            throw new ExternalTokenException("Facebook token is invalid");
        debugResponse.EnsureSuccessStatusCode();

        var debug = await debugResponse.Content.ReadFromJsonAsync<FacebookDebugTokenResponse>()
            ?? throw new HttpRequestException("Facebook debug_token returned no response");

        var data = debug.Data ?? throw new HttpRequestException("Facebook debug_token missing data");

        if (!data.IsValid)
            throw new ExternalTokenException("Facebook token is invalid");

        if (!string.Equals(data.AppId, appId, StringComparison.Ordinal))
            throw new ExternalTokenException("Facebook token was not issued for this app");

        if (data.ExpiresAt.HasValue)
        {
            var expiresAt = DateTimeOffset.FromUnixTimeSeconds(data.ExpiresAt.Value).UtcDateTime;
            if (expiresAt <= DateTime.UtcNow)
                throw new ExternalTokenException("Facebook token is expired");
        }

        var userId = data.UserId;
        if (string.IsNullOrWhiteSpace(userId))
            throw new ExternalTokenException("Facebook token does not contain a user_id");

        // 2) Fetch user profile (optional fields based on granted scopes)
        var meUrl = $"https://graph.facebook.com/me?fields=id,name,email&access_token={Uri.EscapeDataString(accessToken)}";
        var me = await _http.GetFromJsonAsync<FacebookMeResponse>(meUrl)
            ?? throw new HttpRequestException("Facebook /me returned no response");

        if (string.IsNullOrWhiteSpace(me.Id) || !string.Equals(me.Id, userId, StringComparison.Ordinal))
            throw new ExternalTokenException("Facebook token user_id did not match /me id");

        return new ExternalAuthIdentity(
            Provider: ExternalAuthProvider.Facebook,
            ProviderUserId: me.Id,
            Email: me.Email,
            // Facebook does not reliably provide an email-verified claim.
            // Keep this false; our app should not mark emails as verified based only on presence.
            EmailVerified: false,
            DisplayName: me.Name
        );
    }

    private sealed class FacebookDebugTokenResponse
    {
        [JsonPropertyName("data")]
        public FacebookDebugTokenData? Data { get; set; }
    }

    private sealed class FacebookDebugTokenData
    {
        [JsonPropertyName("app_id")]
        public string? AppId { get; set; }

        [JsonPropertyName("is_valid")]
        public bool IsValid { get; set; }

        [JsonPropertyName("user_id")]
        public string? UserId { get; set; }

        [JsonPropertyName("expires_at")]
        public long? ExpiresAt { get; set; }
    }

    private sealed class FacebookMeResponse
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("name")]
        public string? Name { get; set; }
    }
}