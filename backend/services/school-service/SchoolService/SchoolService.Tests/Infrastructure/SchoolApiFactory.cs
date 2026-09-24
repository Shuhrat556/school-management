using System.Data.Common;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Tests.Infrastructure;

// Boots the real school-service pipeline (auth, routing, middleware) against an
// in-memory SQLite database. Startup DB init and Consul registration are off.
public class SchoolApiFactory : WebApplicationFactory<Program>
{
    private readonly DbConnection _connection;

    public SchoolApiFactory()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Database:InitializeOnStartup", "false");
        builder.UseSetting("Consul:Enabled", "false");
        builder.UseSetting("Jwt:Secret", TestTokens.Secret);
        builder.UseSetting("Jwt:Issuer", TestTokens.Issuer);
        builder.UseSetting("Jwt:Audience", TestTokens.Audience);

        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<SchoolDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<SchoolDbContext>>();
            services.AddDbContext<SchoolDbContext>(options => options.UseSqlite(_connection));
        });
    }

    protected override void ConfigureClient(HttpClient client)
    {
        base.ConfigureClient(client);
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<SchoolDbContext>().Database.EnsureCreated();
    }

    public HttpClient CreateClientAs(string role, Guid? authUserId = null)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", TestTokens.Create(role, authUserId ?? Guid.NewGuid()));
        return client;
    }

    public async Task<T> WithDbAsync<T>(Func<SchoolDbContext, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<SchoolDbContext>();
        db.Database.EnsureCreated();
        return await action(db);
    }

    public Task WithDbAsync(Func<SchoolDbContext, Task> action)
        => WithDbAsync(async db => { await action(db); return true; });

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing) _connection.Dispose();
    }
}
