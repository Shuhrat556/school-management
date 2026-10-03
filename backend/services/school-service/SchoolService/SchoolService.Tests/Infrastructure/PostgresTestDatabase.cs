using Microsoft.EntityFrameworkCore;
using Npgsql;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Tests.Infrastructure;

// A throwaway PostgreSQL database (see PostgresFactAttribute) that is dropped even when the test fails.
public sealed class PostgresTestDatabase : IAsyncDisposable
{
    public required SchoolDbContext Db { get; init; }

    public static async Task<PostgresTestDatabase> CreateAsync()
    {
        var admin = new NpgsqlConnectionStringBuilder(Environment.GetEnvironmentVariable(PostgresFactAttribute.Variable));
        var name = $"school_test_{Guid.NewGuid():N}";
        await using (var connection = new NpgsqlConnection(admin.ConnectionString))
        {
            await connection.OpenAsync();
            await using var create = new NpgsqlCommand($"CREATE DATABASE \"{name}\"", connection);
            await create.ExecuteNonQueryAsync();
        }

        admin.Database = name;
        var options = new DbContextOptionsBuilder<SchoolDbContext>().UseNpgsql(admin.ConnectionString).Options;
        return new PostgresTestDatabase { Db = new SchoolDbContext(options) };
    }

    public async ValueTask DisposeAsync()
    {
        await Db.Database.EnsureDeletedAsync();
        await Db.DisposeAsync();
    }
}
