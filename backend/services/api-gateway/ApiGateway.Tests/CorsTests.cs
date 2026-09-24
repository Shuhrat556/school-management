using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace ApiGateway.Tests;

// BUGS B6: the gateway answered every origin with Access-Control-Allow-Origin: *.
public class CorsTests
{
    private sealed class GatewayFactory(string environment, string? allowedOrigin = null) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(environment);
            if (allowedOrigin != null)
                builder.UseSetting("Cors:AllowedOrigins:0", allowedOrigin);
        }
    }

    private static async Task<HttpResponseMessage> PreflightAsync(WebApplicationFactory<Program> factory, string origin)
    {
        var request = new HttpRequestMessage(HttpMethod.Options, "/health");
        request.Headers.Add("Origin", origin);
        request.Headers.Add("Access-Control-Request-Method", "GET");
        return await factory.CreateClient().SendAsync(request);
    }

    [Fact]
    public async Task Production_rejects_unknown_origins()
    {
        using var factory = new GatewayFactory("Production");

        var response = await PreflightAsync(factory, "https://evil.example");

        Assert.False(response.Headers.Contains("Access-Control-Allow-Origin"));
    }

    [Fact]
    public async Task Production_allows_configured_origin()
    {
        using var factory = new GatewayFactory("Production", "https://school.example");

        var response = await PreflightAsync(factory, "https://school.example");

        Assert.Equal("https://school.example", response.Headers.GetValues("Access-Control-Allow-Origin").Single());
    }

    [Fact]
    public async Task Development_allows_any_origin()
    {
        using var factory = new GatewayFactory("Development");

        var response = await PreflightAsync(factory, "http://localhost:54321");

        Assert.True(response.Headers.Contains("Access-Control-Allow-Origin"));
    }

    [Fact]
    public async Task Health_endpoint_answers()
    {
        using var factory = new GatewayFactory("Production");

        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
