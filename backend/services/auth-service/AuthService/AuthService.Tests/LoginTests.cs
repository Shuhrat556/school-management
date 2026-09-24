using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Infrastructure.Data;
using AuthService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

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

    // BUGS B10: PasswordHash is a nullable column; a row without a hash
    // (OAuth-only account) made password login throw.
    [Fact]
    public async Task Password_login_to_an_account_without_password_is_401_not_500()
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, password: "");
        await factory.WithScopeAsync(sp => sp.GetRequiredService<AuthDbContext>().Database
            .ExecuteSqlInterpolatedAsync($"UPDATE \"Users\" SET \"PasswordHash\" = NULL WHERE \"Id\" = {user.Id}"));

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/authenticate", new { email, password = "anything" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // BUGS B8: "email not verified" was returned even for a wrong password,
    // which told anyone that the address has an account.
    [Fact]
    public async Task Unverified_account_is_only_revealed_to_someone_with_the_password()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!", verified: false);
        var client = factory.CreateClient();

        var wrong = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "wrong" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        var right = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" }))
            .Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal("INVALID_CREDENTIALS", wrong.GetProperty("code").GetString());
        Assert.Equal("EMAIL_NOT_VERIFIED", right.GetProperty("code").GetString());
    }
}
