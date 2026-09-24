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
    private static async Task<SchoolDbContext> NewDatabaseAsync()
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
        return new SchoolDbContext(options);
    }

    [PostgresFact]
    public async Task Fresh_database_is_built_by_migrations()
    {
        await using var db = await NewDatabaseAsync();

        Assert.False(await LegacySchemaBaseline.ApplyAsync(db));
        await db.Database.MigrateAsync();

        Assert.Equal(db.Database.GetMigrations(), await db.Database.GetAppliedMigrationsAsync());
        Assert.Empty(await db.Database.GetPendingMigrationsAsync());
        await db.Database.EnsureDeletedAsync();
    }

    [PostgresFact]
    public async Task Database_created_by_EnsureCreated_is_baselined_and_keeps_its_data()
    {
        await using var db = await NewDatabaseAsync();
        await db.Database.EnsureCreatedAsync();
        db.Departments.Add(new Department("Computer Science"));
        await db.SaveChangesAsync();

        Assert.True(await LegacySchemaBaseline.ApplyAsync(db));
        await db.Database.MigrateAsync();

        Assert.Contains(LegacySchemaBaseline.BaselineMigration, await db.Database.GetAppliedMigrationsAsync());
        Assert.Empty(await db.Database.GetPendingMigrationsAsync());
        Assert.Equal(1, await db.Departments.CountAsync());
        Assert.False(await LegacySchemaBaseline.ApplyAsync(db));
        await db.Database.EnsureDeletedAsync();
    }

    [PostgresFact]
    public async Task Every_migration_can_be_rolled_back()
    {
        await using var db = await NewDatabaseAsync();
        await db.Database.MigrateAsync();

        await db.GetService<IMigrator>().MigrateAsync(Migration.InitialDatabase);

        Assert.Empty(await db.Database.GetAppliedMigrationsAsync());
        await db.Database.EnsureDeletedAsync();
    }
}
