using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests;

public class LoginTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    [Fact]
    public async Task Valid_credentials_return_a_token_pair()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(string.IsNullOrEmpty(body.GetProperty("token").GetString()));
        Assert.False(string.IsNullOrEmpty(body.GetProperty("refreshToken").GetString()));
    }

    [Fact]
    public async Task Wrong_password_is_401()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/authenticate", new { email, password = "nope" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Refresh_rotates_the_token()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        var first = login.GetProperty("refreshToken").GetString();

        var refreshed = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = first });
        var reused = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = first });

        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, reused.StatusCode);
    }
}
