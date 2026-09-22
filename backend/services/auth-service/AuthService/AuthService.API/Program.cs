using AuthService.Application.Interfaces;
using AuthService.Application.Services;
using AuthService.Infrastructure.Data;
using AuthService.Infrastructure.Repositories;
using AuthService.Infrastructure.Services;
using AuthService.Infrastructure.Settings;
using AuthService.Infrastructure.Seed;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using Consul;
using AuthService.API.Middleware;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .SelectMany(e => e.Value!.Errors.Select(er => er.ErrorMessage))
                .ToList();

            var traceId = System.Diagnostics.Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;

            var response = new
            {
                message = "Validation failed.",
                code = "VALIDATION_ERROR",
                details = string.Join(" ", errors),
                traceId,
                statusCode = 400,
                path = context.HttpContext.Request.Path.Value
            };

            return new Microsoft.AspNetCore.Mvc.BadRequestObjectResult(response);
        };
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Paste the accessToken from POST /api/auth/authenticate"
    });
    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = []
    });
});
builder.Services.AddHttpClient();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = false;
        options.TokenValidationParameters = JwtConfig.CreateValidationParameters(builder.Configuration);
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

builder.Services.AddDbContext<AuthDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("AuthDb")));

builder.Services.AddScoped<IExternalAuthValidator, ExternalAuthValidator>();
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<DataSeeder>();

builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();

builder.Services.AddSingleton<IConsulClient, ConsulClient>(sp => new ConsulClient(cfg =>
{
    var consulHost = builder.Configuration["consul:host"] ?? "localhost";
    var consulPort = int.TryParse(builder.Configuration["consul:port"], out var p) ? p : 8500;
    cfg.Address = new Uri($"http://{consulHost}:{consulPort}");
}));

var app = builder.Build();

app.UseMiddleware<GlobalExceptionMiddleware>();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AuthDbContext>();

    var dbMaxAttempts = 10;
    var dbDelay = TimeSpan.FromSeconds(2);
    for (int attempt = 1; attempt <= dbMaxAttempts; attempt++)
    {
        try
        {
            var connection = db.Database.GetDbConnection();
            await connection.OpenAsync();
            await connection.CloseAsync();

            db.Database.Migrate();

            var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();
            await seeder.SeedDataAsync();

            Console.WriteLine("AuthService database migrated and seeded successfully.");
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Attempt {attempt} to connect to database failed: {ex.Message}");
            if (attempt == dbMaxAttempts)
                throw;

            await Task.Delay(dbDelay);
            dbDelay = TimeSpan.FromSeconds(dbDelay.TotalSeconds * 2);
        }
    }
}

if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "auth-service" }));

app.MapControllers();

_ = Task.Run(async () =>
{
    var consulClient = app.Services.GetRequiredService<IConsulClient>();
    var registration = new AgentServiceRegistration()
    {
        ID = "auth-service-" + Guid.NewGuid().ToString(),
        Name = builder.Configuration["spring:application:name"] ?? "auth-service",
        Address = "auth-service",
        Port = 8080,
        Tags = new[] { "auth", "api" },
        Check = new AgentServiceCheck
        {
            HTTP = "http://auth-service:8080/health",
            Interval = TimeSpan.FromSeconds(10),
            DeregisterCriticalServiceAfter = TimeSpan.FromMinutes(1)
        }
    };

    var maxAttempts = 10;
    var delay = TimeSpan.FromSeconds(3);
    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            await consulClient.Agent.ServiceRegister(registration);
            Console.WriteLine("AuthService registered with Consul.");

            app.Lifetime.ApplicationStopping.Register(async () =>
            {
                try
                {
                    await consulClient.Agent.ServiceDeregister(registration.ID);
                    Console.WriteLine("AuthService deregistered from Consul.");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to deregister from Consul: {ex.Message}");
                }
            });
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Attempt {attempt} to register with Consul failed: {ex.Message}");
            if (attempt == maxAttempts)
            {
                Console.WriteLine("Could not register with Consul, continuing without it.");
                break;
            }
            await Task.Delay(delay);
        }
    }
});

app.Run();
