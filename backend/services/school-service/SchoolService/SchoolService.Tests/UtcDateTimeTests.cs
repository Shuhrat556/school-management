using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B50: a date posted without a zone ("dateOfBirth": "2006-05-05") binds as
// DateTime Kind=Unspecified, and Npgsql refuses to write that to a
// "timestamp with time zone" column — creating a student with a birth date was a 500.
// SQLite does not check Kind, so this runs against PostgreSQL only.
public class UtcDateTimeTests
{
    private static readonly DateTime Birthday = new(2006, 5, 5); // Kind=Unspecified, as model binding gives it

    [PostgresFact]
    public async Task Student_and_teacher_with_an_unzoned_birth_date_are_saved_as_utc()
    {
        await using var temp = await PostgresTestDatabase.CreateAsync();
        var db = temp.Db;
        await db.Database.MigrateAsync();

        var student = new Student("Shuhrat", "Shoimardonov");
        student.UpdateBasicInfo("Shuhrat", "Shoimardonov", "Male", Birthday, "+992977638855", null, "s@school.test");
        var teacher = new Teacher("Ann", "Lee");
        teacher.UpdateBasicInfo("Ann", "Lee", null, Birthday, null, "t@school.test", null);
        db.AddRange(student, teacher);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var saved = await db.Students.SingleAsync(s => s.DateOfBirth == Birthday);
        Assert.Equal(new DateTime(2006, 5, 5, 0, 0, 0, DateTimeKind.Utc), saved.DateOfBirth);
        Assert.Equal(DateTimeKind.Utc, saved.DateOfBirth!.Value.Kind);
        Assert.Equal(Birthday.Date, (await db.Teachers.SingleAsync()).DateOfBirth!.Value.Date);
    }

    [PostgresFact]
    public async Task Local_times_are_converted_to_utc()
    {
        await using var temp = await PostgresTestDatabase.CreateAsync();
        var db = temp.Db;
        await db.Database.MigrateAsync();

        var local = new DateTime(2026, 10, 3, 12, 0, 0, DateTimeKind.Local);
        var student = new Student("Local", "Time");
        student.UpdateBasicInfo("Local", "Time", null, local, null, null);
        db.Students.Add(student);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        Assert.Equal(local.ToUniversalTime(), (await db.Students.SingleAsync()).DateOfBirth);
    }
}
