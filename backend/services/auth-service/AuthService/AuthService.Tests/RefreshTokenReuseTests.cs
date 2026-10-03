using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Domain.Entities;
using AuthService.Infrastructure.Data;
using AuthService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AuthService.Tests;

// A rotated refresh token that shows up again has leaked: end every session of
// the user (RFC 9700 §4.14.2). Expired tokens are dropped instead of piling up.
public class RefreshTokenReuseTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private static async Task<string> TokenFromAsync(HttpResponseMessage response)
        => (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("refreshToken").GetString()!;

    private async Task<(HttpClient Client, Guid UserId, string Token)> SignInAsync()
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();
        var login = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" });
        return (client, user.Id, await TokenFromAsync(login));
    }

    private static Task<HttpResponseMessage> RefreshAsync(HttpClient client, string token)
        => client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = token });

    // Moves the user's revoked tokens' revocation back in time, past the reuse grace period.
    private Task AgeRevocationsAsync(Guid userId)
        => factory.WithScopeAsync(async sp =>
        {
            var db = sp.GetRequiredService<AuthDbContext>();
            var revoked = await db.Set<RefreshToken>().Where(t => t.UserId == userId && t.RevokedAt != null).ToListAsync();
            foreach (var token in revoked)
                db.Entry(token).Property(t => t.RevokedAt).CurrentValue = DateTime.UtcNow.AddMinutes(-5);
            await db.SaveChangesAsync();
            return true;
        });

    [Fact]
    public async Task Reusing_a_rotated_token_ends_every_session()
    {
        var (client, userId, first) = await SignInAsync();
        var second = await TokenFromAsync(await RefreshAsync(client, first));
        await AgeRevocationsAsync(userId);

        var replay = await RefreshAsync(client, first);
        var current = await RefreshAsync(client, second);

        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, current.StatusCode);
    }

    [Fact]
    public async Task A_double_submit_right_after_rotation_keeps_the_session()
    {
        var (client, _, first) = await SignInAsync();
        var second = await TokenFromAsync(await RefreshAsync(client, first));

        var duplicate = await RefreshAsync(client, first);
        var current = await RefreshAsync(client, second);

        Assert.Equal(HttpStatusCode.Unauthorized, duplicate.StatusCode);
        Assert.Equal(HttpStatusCode.OK, current.StatusCode);
    }

    [Fact]
    public async Task Expired_tokens_are_dropped_when_a_new_one_is_issued()
    {
        var (client, userId, first) = await SignInAsync();
        await factory.WithScopeAsync(async sp =>
        {
            var db = sp.GetRequiredService<AuthDbContext>();
            var token = await db.Set<RefreshToken>().SingleAsync(t => t.UserId == userId);
            db.Entry(token).Property(t => t.ExpiresAt).CurrentValue = DateTime.UtcNow.AddDays(-1);
            await db.SaveChangesAsync();
            return true;
        });

        await SignInAgainAsync(client, userId);

        var remaining = await factory.WithScopeAsync(sp => sp.GetRequiredService<AuthDbContext>()
            .Set<RefreshToken>().CountAsync(t => t.UserId == userId));
        Assert.Equal(1, remaining);
    }

    private async Task SignInAgainAsync(HttpClient client, Guid userId)
    {
        var email = await factory.WithScopeAsync(sp => sp.GetRequiredService<AuthDbContext>()
            .Set<User>().Where(u => u.Id == userId).Select(u => u.Email).SingleAsync());
        var login = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }
}
