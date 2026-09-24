using System.Data.Common;
using AuthService.Application.Interfaces;
using AuthService.Domain.Entities;
using AuthService.Domain.Enums;
using AuthService.Infrastructure.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace AuthService.Tests.Infrastructure;

// Boots the real auth-service pipeline against an in-memory SQLite database,
// with outgoing email captured instead of sent.
public class AuthApiFactory : WebApplicationFactory<Program>
{
    public const string JwtSecret = "test-only-signing-key-0123456789abcdef0123456789";

    private readonly DbConnection _connection;

    public FakeEmailSender Emails { get; } = new();

    public AuthApiFactory()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Database:InitializeOnStartup", "false");
        builder.UseSetting("Consul:Enabled", "false");
        builder.UseSetting("Jwt:Secret", JwtSecret);
        builder.UseSetting("Jwt:Issuer", "AuthService");
        builder.UseSetting("Jwt:Audience", "AuthServiceClients");
        // Every test request shares one client IP; keep the per-IP limits out of the way.
        foreach (var policy in new[] { "login", "codes", "refresh" })
            builder.UseSetting($"RateLimiting:{policy}:PermitLimit", "100000");

        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AuthDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<AuthDbContext>>();
            services.AddDbContext<AuthDbContext>(options => options.UseSqlite(_connection));

            services.RemoveAll<IEmailSender>();
            services.AddSingleton<IEmailSender>(Emails);
        });
    }

    protected override void ConfigureClient(HttpClient client)
    {
        base.ConfigureClient(client);
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<AuthDbContext>().Database.EnsureCreated();
    }

    public async Task<T> WithScopeAsync<T>(Func<IServiceProvider, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<AuthDbContext>().Database.EnsureCreated();
        return await action(scope.ServiceProvider);
    }

    // Creates an account the way an admin would (email already verified).
    public Task<User> CreateUserAsync(string email, string password, UserRole role = UserRole.Student, bool verified = true)
        => WithScopeAsync(async sp =>
        {
            var user = new User(email, "Test User", role);
            if (password.Length > 0)
                user.SetPasswordHash(sp.GetRequiredService<IPasswordHasher>().HashPassword(user, password));
            if (verified)
                user.VerifyEmail();
            await sp.GetRequiredService<IUserRepository>().AddAsync(user);
            return user;
        });

    public static string NewEmail() => $"u{Guid.NewGuid():N}@school.test";

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing) _connection.Dispose();
    }
}

public class FakeEmailSender : IEmailSender
{
    public List<(string To, string Subject, string Body)> Sent { get; } = new();

    public Task SendEmailAsync(string toEmail, string subject, string htmlBody)
    {
        lock (Sent) Sent.Add((toEmail, subject, htmlBody));
        return Task.CompletedTask;
    }
}
