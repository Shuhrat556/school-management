namespace SchoolService.Tests.Infrastructure;

// Runs only when SCHOOL_TEST_POSTGRES holds a connection string to a server where
// the test user may create databases, e.g.
// "Host=127.0.0.1;Port=55432;Username=postgres". Migrations are PostgreSQL-specific.
public sealed class PostgresFactAttribute : FactAttribute
{
    public const string Variable = "SCHOOL_TEST_POSTGRES";

    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(Variable)))
            Skip = $"Set {Variable} to run PostgreSQL migration tests.";
    }
}
