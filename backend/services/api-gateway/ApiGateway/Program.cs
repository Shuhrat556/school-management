using System.Diagnostics;
using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.HttpOverrides;
using Yarp.ReverseProxy;
using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Browser clients normally call the API through their own origin (admin-web
// rewrites, web-app nginx), so cross-origin access is only for the origins
// listed in Cors:AllowedOrigins — or anything in Development.
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (builder.Environment.IsDevelopment())
            policy.AllowAnyOrigin();
        else
            policy.WithOrigins(allowedOrigins);
        policy.AllowAnyMethod().AllowAnyHeader();
    });
});

builder.Services.AddSingleton<Consul.IConsulClient>(sp => new Consul.ConsulClient(cfg =>
{
    var consulHost = builder.Configuration["consul:host"] ?? "consul";
    var consulPort = int.TryParse(builder.Configuration["consul:port"], out var p) ? p : 8500;
    cfg.Address = new Uri($"http://{consulHost}:{consulPort}");
}));

// admin-web and the web-app nginx sit in front of the gateway on the private
// Docker network; trust their X-Forwarded-For so YARP passes the real client
// IP on to the services (auth-service rate-limits per client IP).
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
    foreach (var network in new[] { "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "::1/128" })
        options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(network));
});

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

var app = builder.Build();

app.UseForwardedHeaders();

_ = Task.Run(async () =>
{
    var consulHost = builder.Configuration["consul:host"] ?? "consul";
    var consulPort = int.TryParse(builder.Configuration["consul:port"], out var p) ? p : 8500;

    var maxAttempts = 15;
    var delay = TimeSpan.FromSeconds(2);

    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            var (routes, clusters) = ApiGateway.DiscoveryConfigFactory.BuildFromConsul(consulHost, consulPort);
            Console.WriteLine($"Discovered {clusters.Count} service clusters from Consul.");
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Attempt {attempt} to discover services from Consul failed: {ex.Message}");
            if (attempt == maxAttempts)
            {
                Console.WriteLine("Could not reach Consul, falling back to static YARP configuration.");
                break;
            }
            await Task.Delay(delay);
        }
    }
});

if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    // One Swagger UI for the whole API: the downstream documents are proxied
    // through the gateway (see the *-swagger-route entries in appsettings.json),
    // so "Try it out" calls go through the gateway like real clients do.
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/auth/v1/swagger.json", "Auth Service");
        options.SwaggerEndpoint("/swagger/school/v1/swagger.json", "School Service");
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "API Gateway");
    });
}

app.UseCors();

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "api-gateway" }));

app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (Exception exception)
    {
        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

        logger.LogError(
            exception,
            "Unhandled gateway exception for {Method} {Path}. TraceId: {TraceId}",
            context.Request.Method,
            context.Request.Path,
            traceId);

        context.Response.ContentType = "application/json";

        var response = MapGatewayException(exception, traceId, context.Request.Path.Value, app.Environment.IsDevelopment());
        context.Response.StatusCode = response.statusCode;
        await context.Response.WriteAsync(JsonSerializer.Serialize(response));
    }
});

app.MapReverseProxy();

app.Run();

static GatewayErrorResponse MapGatewayException(Exception exception, string traceId, string? path, bool includeDebugDetails)
{
    var response = new GatewayErrorResponse
    {
        message = "The gateway could not complete the request.",
        code = "BAD_GATEWAY",
        traceId = traceId,
        statusCode = (int)HttpStatusCode.BadGateway,
        path = path,
        details = includeDebugDetails ? exception.Message : $"See traceId '{traceId}' in gateway logs.",
        stackTrace = includeDebugDetails ? exception.StackTrace : null,
    };

    switch (exception)
    {
        case HttpRequestException ex:
            response.message = "The gateway could not reach an upstream service.";
            response.code = "UPSTREAM_UNAVAILABLE";
            response.details = includeDebugDetails ? ex.Message : response.details;
            break;

        case TaskCanceledException ex:
            response.message = "The gateway timed out while waiting for an upstream service.";
            response.code = "UPSTREAM_TIMEOUT";
            response.statusCode = (int)HttpStatusCode.GatewayTimeout;
            response.details = includeDebugDetails ? ex.Message : response.details;
            break;

        case BadHttpRequestException ex:
            response.message = "The gateway rejected the incoming request.";
            response.code = "BAD_REQUEST";
            response.statusCode = (int)HttpStatusCode.BadRequest;
            response.details = ex.Message;
            break;
    }

    return response;
}

public class GatewayErrorResponse
{
    public string message { get; set; } = string.Empty;
    public string code { get; set; } = string.Empty;
    public string? details { get; set; }
    public string? stackTrace { get; set; }
    public string? traceId { get; set; }
    public int statusCode { get; set; }
    public string? path { get; set; }
}
