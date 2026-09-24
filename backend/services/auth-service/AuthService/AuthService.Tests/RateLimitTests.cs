using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

namespace AuthService.Tests;

// BUGS B3: nothing limited how fast the anonymous auth endpoints could be called.
public class RateLimitTests
{
    // Low limits, and the TCP peer address taken from a test header so the
    // forwarded-headers trust rules can be exercised.
    private sealed class LimitedFactory : AuthApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.UseSetting("RateLimiting:login:PermitLimit", "3");
            builder.UseSetting("RateLimiting:codes:PermitLimit", "2");
            builder.ConfigureServices(services => services.AddSingleton<IStartupFilter, PeerAddressFilter>());
        }
    }

    private sealed class PeerAddressFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use((context, nextMiddleware) =>
            {
                if (context.Request.Headers.TryGetValue("X-Test-Peer", out var peer))
                    context.Connection.RemoteIpAddress = IPAddress.Parse(peer!);
                return nextMiddleware(context);
            });
            next(app);
        };
    }

    private static HttpRequestMessage Login(string peer, string? forwardedFor = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/auth/authenticate")
        {
            Content = JsonContent.Create(new { email = "nobody@school.test", password = "x" })
        };
        request.Headers.Add("X-Test-Peer", peer);
        if (forwardedFor != null)
            request.Headers.Add("X-Forwarded-For", forwardedFor);
        return request;
    }

    [Fact]
    public async Task Login_is_limited_per_client_ip()
    {
        using var factory = new LimitedFactory();
        var client = factory.CreateClient();

        for (var i = 0; i < 3; i++)
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.SendAsync(Login("203.0.113.10"))).StatusCode);
        var limited = await client.SendAsync(Login("203.0.113.10"));
        var otherClient = await client.SendAsync(Login("203.0.113.11"));

        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.True(limited.Headers.Contains("Retry-After"));
        var body = await limited.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("TOO_MANY_REQUESTS", body.GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, otherClient.StatusCode);
    }

    [Fact]
    public async Task Clients_behind_the_gateway_are_told_apart_by_forwarded_ip()
    {
        using var factory = new LimitedFactory();
        var client = factory.CreateClient();
        const string gateway = "172.18.0.5";

        for (var i = 0; i < 3; i++)
            await client.SendAsync(Login(gateway, forwardedFor: "198.51.100.1"));
        var sameUser = await client.SendAsync(Login(gateway, forwardedFor: "198.51.100.1"));
        var anotherUser = await client.SendAsync(Login(gateway, forwardedFor: "198.51.100.2"));

        Assert.Equal(HttpStatusCode.TooManyRequests, sameUser.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, anotherUser.StatusCode);
    }

    [Fact]
    public async Task Forwarded_ip_from_an_untrusted_peer_is_ignored()
    {
        using var factory = new LimitedFactory();
        var client = factory.CreateClient();
        const string attacker = "203.0.113.66";

        for (var i = 0; i < 3; i++)
            await client.SendAsync(Login(attacker, forwardedFor: $"198.51.100.{i + 10}"));
        var spoofed = await client.SendAsync(Login(attacker, forwardedFor: "198.51.100.99"));

        Assert.Equal(HttpStatusCode.TooManyRequests, spoofed.StatusCode);
    }

    [Fact]
    public async Task Code_requests_are_limited()
    {
        using var factory = new LimitedFactory();
        var client = factory.CreateClient();

        HttpResponseMessage last = null!;
        for (var i = 0; i < 3; i++)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "/api/auth/request-password-reset")
            {
                Content = JsonContent.Create(new { email = $"x{i}@school.test" })
            };
            request.Headers.Add("X-Test-Peer", "203.0.113.20");
            last = await client.SendAsync(request);
        }

        Assert.Equal(HttpStatusCode.TooManyRequests, last.StatusCode);
    }
}
