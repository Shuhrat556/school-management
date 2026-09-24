using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Infrastructure.Data;
using AuthService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AuthService.Tests;

// BUGS B7: refresh tokens were stored as issued, so a copy of the database was
// enough to take over every active session.
public class RefreshTokenStorageTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private async Task<string> LoginAsync(HttpClient client, string email)
    {
        var body = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        return body.GetProperty("refreshToken").GetString()!;
    }

    [Fact]
    public async Task Issued_refresh_token_is_not_stored_in_plain_text()
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, "Password123!");

        var issued = await LoginAsync(factory.CreateClient(), email);

        var stored = await factory.WithScopeAsync(sp => sp.GetRequiredService<AuthDbContext>()
            .Set<AuthService.Domain.Entities.RefreshToken>().AsNoTracking()
            .Where(t => t.UserId == user.Id).Select(t => t.Token).ToListAsync());
        Assert.Single(stored);
        Assert.NotEqual(issued, stored[0]);
    }

    [Fact]
    public async Task Hashed_tokens_still_refresh_and_log_out()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();
        var first = await LoginAsync(client, email);

        var refreshed = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = first });
        var second = (await refreshed.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("refreshToken").GetString();
        var logout = await (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = second }))
            .Content.ReadFromJsonAsync<bool>();
        var afterLogout = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = second });

        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        Assert.True(logout);
        Assert.Equal(HttpStatusCode.Unauthorized, afterLogout.StatusCode);
    }
}
