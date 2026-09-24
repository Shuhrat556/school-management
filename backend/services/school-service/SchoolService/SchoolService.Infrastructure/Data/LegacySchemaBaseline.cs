using System.Reflection;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace SchoolService.Infrastructure.Data;

// school_db used to be created with EnsureCreated() plus the hand-written SQL
// below, so existing databases have the full schema but no migration history.
// The migrations up to BaselineMigration produce exactly that schema (compared
// column by column, index by index on PostgreSQL 16), so for such a database we
// patch any very old copy with the old idempotent SQL and record those
// migrations as applied. Fresh databases and ones that already have history are
// left to Database.Migrate().
public static class LegacySchemaBaseline
{
    public const string BaselineMigration = "20260409091051_Add_Department_Entity_And_Relationships";

    // Returns true when a legacy database was baselined.
    public static async Task<bool> ApplyAsync(SchoolDbContext db, CancellationToken cancellationToken = default)
    {
        // Only PostgreSQL databases were ever created the old way. (Npgsql's
        // IHistoryRepository.ExistsAsync reports true even when the table is
        // missing, so check the catalog directly.)
        if (!db.Database.IsNpgsql()
            || await TableExistsAsync(db, "__EFMigrationsHistory", cancellationToken)
            || !await TableExistsAsync(db, "Students", cancellationToken))
            return false;

        await db.Database.ExecuteSqlRawAsync(LegacyPatchSql, cancellationToken);

        var history = db.GetService<IHistoryRepository>();
        await db.Database.ExecuteSqlRawAsync(history.GetCreateIfNotExistsScript(), cancellationToken);

        var productVersion = typeof(DbContext).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion.Split('+')[0] ?? "10.0";
        foreach (var migration in db.Database.GetMigrations().Where(m => string.CompareOrdinal(m, BaselineMigration) <= 0))
            await db.Database.ExecuteSqlRawAsync(
                history.GetInsertScript(new HistoryRow(migration, productVersion)), cancellationToken);

        return true;
    }

    private static Task<bool> TableExistsAsync(SchoolDbContext db, string table, CancellationToken cancellationToken)
        => db.Database
            .SqlQueryRaw<bool>("SELECT to_regclass({0}) IS NOT NULL AS \"Value\"", $"public.\"{table}\"")
            .SingleAsync(cancellationToken);

    // What Program.cs used to run after EnsureCreated(); only needed for
    // databases created before these tables/columns were in the model.
    private const string LegacyPatchSql = """
        ALTER TABLE "Teachers" ADD COLUMN IF NOT EXISTS "AuthUserId" uuid;
        ALTER TABLE "Students" ADD COLUMN IF NOT EXISTS "AuthUserId" uuid;
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_Teachers_AuthUserId"
            ON "Teachers"("AuthUserId") WHERE "AuthUserId" IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS "IX_Students_AuthUserId"
            ON "Students"("AuthUserId") WHERE "AuthUserId" IS NOT NULL;

        CREATE TABLE IF NOT EXISTS "Rooms" (
            "Id" uuid NOT NULL,
            "Name" character varying(150) NOT NULL,
            "Location" character varying(500),
            "Capacity" integer NOT NULL DEFAULT 0,
            "Type" integer NOT NULL,
            "IsActive" boolean NOT NULL,
            "CreatedAt" timestamp with time zone NOT NULL,
            "DeletedAt" timestamp with time zone,
            CONSTRAINT "PK_Rooms" PRIMARY KEY ("Id")
        );

        ALTER TABLE "Classrooms" ADD COLUMN IF NOT EXISTS "RoomId" uuid;
        ALTER TABLE "Classrooms" ADD COLUMN IF NOT EXISTS "Semester" character varying(20);
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_constraint
                WHERE conname = 'FK_Classrooms_Rooms_RoomId'
            ) THEN
                ALTER TABLE "Classrooms"
                ADD CONSTRAINT "FK_Classrooms_Rooms_RoomId"
                FOREIGN KEY ("RoomId") REFERENCES "Rooms"("Id") ON DELETE SET NULL;
            END IF;
        END $$;
        CREATE INDEX IF NOT EXISTS "IX_Classrooms_RoomId" ON "Classrooms"("RoomId");

        CREATE TABLE IF NOT EXISTS "Announcements" (
            "Id" uuid NOT NULL,
            "Title" character varying(200) NOT NULL,
            "Body" text NOT NULL,
            "ClassroomId" uuid,
            "AuthorTeacherId" uuid NOT NULL,
            "PublishedAt" timestamp with time zone,
            "CreatedAt" timestamp with time zone NOT NULL,
            CONSTRAINT "PK_Announcements" PRIMARY KEY ("Id")
        );
        CREATE INDEX IF NOT EXISTS "IX_Announcements_ClassroomId" ON "Announcements"("ClassroomId");
        CREATE INDEX IF NOT EXISTS "IX_Announcements_AuthorTeacherId" ON "Announcements"("AuthorTeacherId");

        CREATE TABLE IF NOT EXISTS "Materials" (
            "Id" uuid NOT NULL,
            "ClassroomId" uuid NOT NULL,
            "Title" character varying(200) NOT NULL,
            "Description" text,
            "Url" character varying(1000),
            "Type" integer NOT NULL,
            "IsActive" boolean NOT NULL,
            "CreatedAt" timestamp with time zone NOT NULL,
            "DeletedAt" timestamp with time zone,
            CONSTRAINT "PK_Materials" PRIMARY KEY ("Id")
        );
        CREATE INDEX IF NOT EXISTS "IX_Materials_ClassroomId" ON "Materials"("ClassroomId");

        CREATE TABLE IF NOT EXISTS "Submissions" (
            "Id" uuid NOT NULL,
            "MaterialId" uuid NOT NULL,
            "StudentId" uuid NOT NULL,
            "SubmissionUrl" character varying(1000),
            "SubmittedAt" timestamp with time zone NOT NULL,
            "Grade" numeric(5,2),
            "Feedback" text,
            CONSTRAINT "PK_Submissions" PRIMARY KEY ("Id")
        );
        CREATE INDEX IF NOT EXISTS "IX_Submissions_MaterialId" ON "Submissions"("MaterialId");
        CREATE INDEX IF NOT EXISTS "IX_Submissions_StudentId" ON "Submissions"("StudentId");
        """;
}
