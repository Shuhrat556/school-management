using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B1b: a student could read every student's profile, grades and attendance.
public class StudentDataAccessTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record Seeded(Student Me, Guid MyAuthId, Student Other);

    private async Task<Seeded> SeedAsync()
    {
        var myAuthId = Guid.NewGuid();
        var me = new Student("Me", "Student", myAuthId);
        var other = new Student("Other", "Student", Guid.NewGuid());
        var department = new Department($"Dept {Guid.NewGuid():N}");

        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(me, other);
            db.Departments.Add(department);
            await db.SaveChangesAsync();

            var subject = new Subject($"Math {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();

            db.StudentGrades.AddRange(
                new StudentGrade(me.Id, subject.Id, 91, "1"),
                new StudentGrade(other.Id, subject.Id, 55, "1"));
            db.Attendances.Add(new Attendance(other.Id, null, new DateOnly(2026, 9, 1), AttendanceStatus.Absent));
            await db.SaveChangesAsync();
        });

        return new Seeded(me, myAuthId, other);
    }

    [Fact]
    public async Task Student_list_is_staff_only()
    {
        Assert.Equal(HttpStatusCode.Forbidden,
            (await factory.CreateClientAs("Student").GetAsync("/api/school/students")).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await factory.CreateClientAs("Teacher").GetAsync("/api/school/students")).StatusCode);
    }

    [Fact]
    public async Task Student_reads_own_profile_but_not_others()
    {
        var s = await SeedAsync();
        var client = factory.CreateClientAs("Student", s.MyAuthId);

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/school/students/{s.Me.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/school/students/{s.Other.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/school/students/{s.Other.Id}/classrooms")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.GetAsync($"/api/school/students/by-auth-user/{s.Other.AuthUserId}")).StatusCode);
    }

    [Fact]
    public async Task Me_returns_linked_profile()
    {
        var s = await SeedAsync();

        var me = await factory.CreateClientAs("Student", s.MyAuthId)
            .GetFromJsonAsync<JsonElement>("/api/school/students/me");

        Assert.Equal(s.Me.Id, me.GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task Me_falls_back_to_email_for_unlinked_profiles_only()
    {
        var email = $"seed-{Guid.NewGuid():N}@school.test";
        var unlinked = new Student("Seed", "Student");
        unlinked.UpdateBasicInfo("Seed", "Student", null, null, null, null, email);
        var linkedEmail = $"linked-{Guid.NewGuid():N}@school.test";
        var linked = new Student("Linked", "Student", Guid.NewGuid());
        linked.UpdateBasicInfo("Linked", "Student", null, null, null, null, linkedEmail);
        await factory.WithDbAsync(async db => { db.Students.AddRange(unlinked, linked); await db.SaveChangesAsync(); });

        var byEmail = await factory.CreateClient()
            .WithToken(TestTokens.Create("Student", Guid.NewGuid(), email.ToUpperInvariant()))
            .GetFromJsonAsync<JsonElement>("/api/school/students/me");
        var stolen = await factory.CreateClient()
            .WithToken(TestTokens.Create("Student", Guid.NewGuid(), linkedEmail))
            .GetAsync("/api/school/students/me");

        Assert.Equal(unlinked.Id, byEmail.GetProperty("id").GetGuid());
        Assert.Equal(HttpStatusCode.NotFound, stolen.StatusCode);
    }

    [Fact]
    public async Task Me_is_only_for_students()
    {
        var response = await factory.CreateClientAs("Parent").GetAsync("/api/school/students/me");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Student_sees_only_own_grades()
    {
        var s = await SeedAsync();
        var client = factory.CreateClientAs("Student", s.MyAuthId);

        var mine = await client.GetFromJsonAsync<JsonElement>("/api/school/grades");
        var others = await client.GetAsync($"/api/school/grades?studentId={s.Other.Id}");

        Assert.All(mine.EnumerateArray(), g => Assert.Equal(s.Me.Id, g.GetProperty("studentId").GetGuid()));
        Assert.Single(mine.EnumerateArray());
        Assert.Equal(HttpStatusCode.Forbidden, others.StatusCode);
    }

    [Fact]
    public async Task Teacher_sees_any_students_grades()
    {
        var s = await SeedAsync();

        var grades = await factory.CreateClientAs("Teacher")
            .GetFromJsonAsync<JsonElement>($"/api/school/grades?studentId={s.Other.Id}");

        Assert.Single(grades.EnumerateArray());
    }

    [Fact]
    public async Task Student_cannot_read_another_students_attendance()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Student", s.MyAuthId)
            .GetAsync($"/api/school/attendance/{s.Other.Id}/history");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Unlinked_parent_cannot_read_student_data()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Parent").GetAsync($"/api/school/students/{s.Me.Id}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Teacher_me_returns_own_profile()
    {
        var authId = Guid.NewGuid();
        var teacher = new Teacher("Own", "Teacher", authId);
        await factory.WithDbAsync(async db => { db.Teachers.Add(teacher); await db.SaveChangesAsync(); });

        var me = await factory.CreateClientAs("Teacher", authId).GetFromJsonAsync<JsonElement>("/api/school/teachers/me");

        Assert.Equal(teacher.Id, me.GetProperty("id").GetGuid());
    }
}
