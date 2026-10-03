using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using AuthService.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace AuthService.Tests;

// BUGS B27: a bad Google or Facebook token made the real validator throw an
// exception the API did not know, so sign-in answered 500 instead of 401.
public class OAuthTokenErrorTests
{
    // Plays graph.facebook.com: answers debug_token with the given status and body.
    private sealed class FakeFacebook(HttpStatusCode status, string body) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") });
    }

    private sealed class ProviderFactory(HttpMessageHandler facebook) : AuthApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.UseSetting("Authentication:Google:ClientId", "test-client.apps.googleusercontent.com");
            builder.UseSetting("Authentication:Facebook:AppId", "test-app");
            builder.UseSetting("Authentication:Facebook:AppSecret", "test-secret");
            builder.ConfigureTestServices(services =>
                services.ConfigureHttpClientDefaults(http => http.ConfigurePrimaryHttpMessageHandler(() => facebook)));
        }
    }

    private static async Task AssertInvalidTokenAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("INVALID_EXTERNAL_TOKEN", body.GetProperty("code").GetString());
    }

    [Fact]
    public async Task Malformed_google_token_is_unauthorized()
    {
        using var factory = new ProviderFactory(new FakeFacebook(HttpStatusCode.OK, "{}"));

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/google", new { idToken = "not-a-jwt" });

        await AssertInvalidTokenAsync(response);
    }

    [Fact]
    public async Task Facebook_token_that_facebook_rejects_is_unauthorized()
    {
        using var factory = new ProviderFactory(new FakeFacebook(HttpStatusCode.OK,
            """{"data":{"app_id":"test-app","is_valid":false}}"""));

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook", new { accessToken = "expired" });

        await AssertInvalidTokenAsync(response);
    }

    [Fact]
    public async Task Malformed_facebook_token_is_unauthorized()
    {
        using var factory = new ProviderFactory(new FakeFacebook(HttpStatusCode.BadRequest,
            """{"error":{"message":"Invalid OAuth access token.","code":190}}"""));

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook", new { accessToken = "garbage" });

        await AssertInvalidTokenAsync(response);
    }

    [Fact]
    public async Task Facebook_token_for_another_app_is_unauthorized()
    {
        using var factory = new ProviderFactory(new FakeFacebook(HttpStatusCode.OK,
            """{"data":{"app_id":"someone-else","is_valid":true,"user_id":"42"}}"""));

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook", new { accessToken = "foreign" });

        await AssertInvalidTokenAsync(response);
    }
}
