using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Domain.Entities;
using AuthService.Domain.Enums;
using AuthService.Infrastructure.Data;
using AuthService.Tests.Infrastructure;
using Microsoft.Extensions.DependencyInjection;

namespace AuthService.Tests;

// F6: a signed-in user links (and unlinks) Google or Facebook, so those sign-ins
// reach their admin-created account. Since B4 this is the only way a Facebook login works.
public class AccountLinkTests(OAuthFactory factory) : IClassFixture<OAuthFactory>
{
    private async Task<(HttpClient Client, Guid UserId)> SignInAsync()
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login.GetProperty("token").GetString());
        return (client, user.Id);
    }

    private static string NewProviderId() => Guid.NewGuid().ToString("N");

    private static Task<HttpResponseMessage> LinkAsync(HttpClient client, string provider, string token)
        => client.PostAsJsonAsync($"/api/auth/logins/{provider}", new { token });

    [Fact]
    public async Task Linked_facebook_signs_in_to_the_account()
    {
        var (client, userId) = await SignInAsync();
        var token = $"{NewProviderId()}|someone@facebook.test|false";

        var link = await LinkAsync(client, "facebook", token);
        var signIn = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook", new { accessToken = token });

        Assert.Equal(HttpStatusCode.OK, link.StatusCode);
        Assert.Equal(HttpStatusCode.OK, signIn.StatusCode);
        Assert.Equal(userId, (await signIn.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("userId").GetGuid());
    }

    [Fact]
    public async Task Linked_logins_are_listed()
    {
        var (client, _) = await SignInAsync();
        await LinkAsync(client, "google", $"{NewProviderId()}|me@gmail.test|true");

        var logins = await client.GetFromJsonAsync<JsonElement>("/api/auth/logins");

        Assert.True(logins.GetProperty("hasPassword").GetBoolean());
        var provider = Assert.Single(logins.GetProperty("logins").EnumerateArray().ToArray()).GetProperty("provider").GetString();
        Assert.Equal("Google", provider);
    }

    [Fact]
    public async Task Linking_the_same_identity_twice_is_harmless()
    {
        var (client, _) = await SignInAsync();
        var token = $"{NewProviderId()}|me@gmail.test|true";

        await LinkAsync(client, "google", token);
        var again = await LinkAsync(client, "google", token);

        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Single((await client.GetFromJsonAsync<JsonElement>("/api/auth/logins")).GetProperty("logins").EnumerateArray());
    }

    [Fact]
    public async Task An_identity_linked_to_someone_else_is_a_conflict()
    {
        var (owner, _) = await SignInAsync();
        var (other, _) = await SignInAsync();
        var token = $"{NewProviderId()}|shared@gmail.test|true";
        await LinkAsync(owner, "google", token);

        var response = await LinkAsync(other, "google", token);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("EXTERNAL_LOGIN_IN_USE", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }

    [Fact]
    public async Task A_second_account_of_the_same_provider_is_a_conflict()
    {
        var (client, _) = await SignInAsync();
        await LinkAsync(client, "google", $"{NewProviderId()}|first@gmail.test|true");

        var response = await LinkAsync(client, "google", $"{NewProviderId()}|second@gmail.test|true");

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Unlinked_provider_no_longer_signs_in()
    {
        var (client, _) = await SignInAsync();
        var token = $"{NewProviderId()}|someone@facebook.test|false";
        await LinkAsync(client, "facebook", token);

        var unlink = await client.DeleteAsync("/api/auth/logins/facebook");
        var signIn = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook", new { accessToken = token });

        Assert.Equal(HttpStatusCode.NoContent, unlink.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, signIn.StatusCode);
    }

    [Fact]
    public async Task The_last_way_to_sign_in_cannot_be_unlinked()
    {
        // An OAuth-only account: no password, one Google login.
        var providerId = NewProviderId();
        var token = $"{providerId}|oauth-only@gmail.test|true";
        await factory.WithScopeAsync(async sp =>
        {
            var db = sp.GetRequiredService<AuthDbContext>();
            var user = new User(AuthApiFactory.NewEmail(), "OAuth Only", UserRole.Student);
            user.SetPasswordHash(null!);
            user.VerifyEmail();
            user.AddExternalLogin(ExternalAuthProvider.Google, providerId);
            db.Add(user);
            await db.SaveChangesAsync();
            return true;
        });
        var client = factory.CreateClient();
        var signIn = await (await client.PostAsJsonAsync("/api/auth/oauth/google", new { idToken = token }))
            .Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", signIn.GetProperty("token").GetString());

        var response = await client.DeleteAsync("/api/auth/logins/google");

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("LAST_SIGN_IN_METHOD", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Unlinking_a_provider_that_is_not_linked_is_not_found()
    {
        var (client, _) = await SignInAsync();

        var response = await client.DeleteAsync("/api/auth/logins/google");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("GET", "/api/auth/logins")]
    [InlineData("POST", "/api/auth/logins/google")]
    [InlineData("DELETE", "/api/auth/logins/google")]
    public async Task Linking_requires_a_signed_in_user(string method, string url)
    {
        var request = new HttpRequestMessage(new HttpMethod(method), url)
        {
            Content = method == "POST" ? JsonContent.Create(new { token = "x|y|true" }) : null
        };

        var response = await factory.CreateClient().SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Unknown_provider_is_not_found()
    {
        var (client, _) = await SignInAsync();

        var response = await LinkAsync(client, "myspace", "x|y|true");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
