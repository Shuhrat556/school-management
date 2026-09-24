using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests;

// BUGS B3: a single account could be brute-forced without any slowdown.
public class AccountLockoutTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private Task<HttpResponseMessage> Login(HttpClient client, string email, string password)
        => client.PostAsJsonAsync("/api/auth/authenticate", new { email, password });

    [Fact]
    public async Task Five_wrong_passwords_lock_the_account_even_for_the_right_one()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();

        for (var i = 0; i < 5; i++)
            Assert.Equal(HttpStatusCode.Unauthorized, (await Login(client, email, $"wrong-{i}")).StatusCode);
        var locked = await Login(client, email, "Password123!");

        Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
        Assert.True(locked.Headers.Contains("Retry-After"));
        var body = await locked.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("ACCOUNT_LOCKED", body.GetProperty("code").GetString());
    }

    [Fact]
    public async Task Successful_login_resets_the_failure_count()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();

        for (var i = 0; i < 4; i++)
            await Login(client, email, "wrong");
        Assert.Equal(HttpStatusCode.OK, (await Login(client, email, "Password123!")).StatusCode);
        for (var i = 0; i < 4; i++)
            await Login(client, email, "wrong");

        Assert.Equal(HttpStatusCode.OK, (await Login(client, email, "Password123!")).StatusCode);
    }

    [Fact]
    public async Task Lockout_on_one_account_does_not_affect_another()
    {
        var victim = AuthApiFactory.NewEmail();
        var bystander = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(victim, "Password123!");
        await factory.CreateUserAsync(bystander, "Password123!");
        var client = factory.CreateClient();

        for (var i = 0; i < 5; i++)
            await Login(client, victim, "wrong");

        Assert.Equal(HttpStatusCode.OK, (await Login(client, bystander, "Password123!")).StatusCode);
    }
}
