using System.Globalization;
using System.Net;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;

namespace AuthService.API.RateLimiting;

// Per-client-IP limits for the anonymous auth endpoints. They are deliberately
// generous: a whole school often shares one public IP. Brute force against a
// single account is handled separately by the account lockout.
public static class AuthRateLimits
{
    public const string Login = "login";
    public const string Codes = "codes";
    public const string Refresh = "refresh";

    public static IServiceCollection AddAuthRateLimits(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            // The gateway, admin-web and the web-app nginx run on the private
            // Docker network; only they may tell us the original client IP.
            options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.KnownIPNetworks.Clear();
            options.KnownProxies.Clear();
            foreach (var network in new[] { "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "::1/128" })
                options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(network));
        });

        services.AddRateLimiter(options =>
        {
            AddPerIpPolicy(options, configuration, Login, permitLimit: 60, window: TimeSpan.FromMinutes(1));
            AddPerIpPolicy(options, configuration, Codes, permitLimit: 20, window: TimeSpan.FromMinutes(10));
            AddPerIpPolicy(options, configuration, Refresh, permitLimit: 120, window: TimeSpan.FromMinutes(1));

            options.OnRejected = async (context, cancellationToken) =>
            {
                var response = context.HttpContext.Response;
                response.StatusCode = StatusCodes.Status429TooManyRequests;
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                    response.Headers.RetryAfter = ((int)retryAfter.TotalSeconds).ToString(CultureInfo.InvariantCulture);

                response.ContentType = "application/json";
                await response.WriteAsync(JsonSerializer.Serialize(new
                {
                    message = "Too many requests. Please wait a moment and try again.",
                    code = "TOO_MANY_REQUESTS",
                    statusCode = 429,
                    path = context.HttpContext.Request.Path.Value
                }), cancellationToken);
            };
        });

        return services;
    }

    // Limits come from RateLimiting:<policy>:PermitLimit / :WindowSeconds when set.
    private static void AddPerIpPolicy(RateLimiterOptions options, IConfiguration configuration,
        string policy, int permitLimit, TimeSpan window)
    {
        var section = configuration.GetSection($"RateLimiting:{policy}");
        var limit = section.GetValue("PermitLimit", permitLimit);
        var seconds = section.GetValue("WindowSeconds", (int)window.TotalSeconds);

        options.AddPolicy(policy, context => RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = limit,
                Window = TimeSpan.FromSeconds(seconds),
                QueueLimit = 0
            }));
    }
}
