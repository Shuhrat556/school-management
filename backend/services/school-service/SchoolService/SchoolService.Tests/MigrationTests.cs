using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B11: school_db was built with EnsureCreated() + hand-written SQL.
public class MigrationTests
{
    // A throwaway database that is dropped even when the test fails.
    private sealed class TempDatabase : IAsyncDisposable
    {
        public required SchoolDbContext Db { get; init; }

        public async ValueTask DisposeAsync()
        {
            await Db.Database.EnsureDeletedAsync();
            await Db.DisposeAsync();
        }
    }

    private static async Task<TempDatabase> NewDatabaseAsync()
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
        return new TempDatabase { Db = new SchoolDbContext(options) };
    }

    [PostgresFact]
    public async Task Fresh_database_is_built_by_migrations()
    {
        await using var temp = await NewDatabaseAsync();
        var db = temp.Db;

        Assert.False(await LegacySchemaBaseline.ApplyAsync(db));
        await db.Database.MigrateAsync();

        Assert.Equal(db.Database.GetMigrations(), await db.Database.GetAppliedMigrationsAsync());
        Assert.Empty(await db.Database.GetPendingMigrationsAsync());
    }

    [PostgresFact]
    public async Task Database_created_by_EnsureCreated_is_baselined_and_keeps_its_data()
    {
        await using var temp = await NewDatabaseAsync();
        var db = temp.Db;
        // What EnsureCreated used to build: the schema at the baseline migration
        // (verified identical) with no history table.
        await db.GetService<IMigrator>().MigrateAsync(LegacySchemaBaseline.BaselineMigration);
        await db.Database.ExecuteSqlRawAsync("DROP TABLE \"__EFMigrationsHistory\"");
        db.Departments.Add(new Department("Computer Science"));
        await db.SaveChangesAsync();

        Assert.True(await LegacySchemaBaseline.ApplyAsync(db));
        await db.Database.MigrateAsync();

        Assert.Contains(LegacySchemaBaseline.BaselineMigration, await db.Database.GetAppliedMigrationsAsync());
        Assert.Empty(await db.Database.GetPendingMigrationsAsync());
        Assert.Equal(1, await db.Departments.CountAsync());
        Assert.False(await LegacySchemaBaseline.ApplyAsync(db));
    }

    [PostgresFact]
    public async Task Every_migration_can_be_rolled_back()
    {
        await using var temp = await NewDatabaseAsync();
        var db = temp.Db;
        await db.Database.MigrateAsync();

        await db.GetService<IMigrator>().MigrateAsync(Migration.InitialDatabase);

        Assert.Empty(await db.Database.GetAppliedMigrationsAsync());
    }

    [PostgresFact]
    public async Task Emails_are_unique_ignoring_case()
    {
        await using var temp = await NewDatabaseAsync();
        var db = temp.Db;
        await db.Database.MigrateAsync();
        var first = new Student("A", "One");
        first.UpdateBasicInfo("A", "One", null, null, null, null, "Same@School.test");
        var second = new Student("B", "Two");
        second.UpdateBasicInfo("B", "Two", null, null, null, null, "same@school.test");
        db.Students.AddRange(first, new Student("No", "Email"), new Student("Also", "NoEmail"));
        await db.SaveChangesAsync();

        db.Students.Add(second);

        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());

        // Once the first profile is deleted its email can be used again.
        db.ChangeTracker.Clear();
        first.SoftDelete();
        db.Students.Update(first);
        await db.SaveChangesAsync();
        db.Students.Add(second);
        await db.SaveChangesAsync();
    }
}
