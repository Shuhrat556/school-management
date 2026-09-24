using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// Students and teachers may edit their own profile, but not someone else's
// and not the fields an admin controls (email, active flag).
public class ProfileOwnershipTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private async Task<Student> SeedStudentAsync(Guid authUserId, string email)
    {
        var student = new Student("Ali", "Valiyev", authUserId);
        student.UpdateBasicInfo("Ali", "Valiyev", null, null, null, null, email);
        await factory.WithDbAsync(async db => { db.Students.Add(student); await db.SaveChangesAsync(); });
        return student;
    }

    private static object StudentUpdate(string email, bool isActive) => new
    {
        firstName = "Alisher",
        lastName = "Valiyev",
        phone = "+998901234567",
        email,
        isActive
    };

    [Fact]
    public async Task Student_can_update_own_profile_but_not_email_or_active_flag()
    {
        var authUserId = Guid.NewGuid();
        var student = await SeedStudentAsync(authUserId, $"own-{authUserId:N}@school.test");

        var response = await factory.CreateClientAs("Student", authUserId)
            .PutAsJsonAsync($"/api/school/students/{student.Id}", StudentUpdate("hijack@evil.test", false));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var saved = await factory.WithDbAsync(db => db.Students.AsNoTracking().SingleAsync(s => s.Id == student.Id));
        Assert.Equal("Alisher", saved.FirstName);
        Assert.Equal("+998901234567", saved.Phone);
        Assert.Equal($"own-{authUserId:N}@school.test", saved.Email);
        Assert.True(saved.IsActive);
    }

    [Fact]
    public async Task Student_cannot_update_another_students_profile()
    {
        var victim = await SeedStudentAsync(Guid.NewGuid(), $"victim-{Guid.NewGuid():N}@school.test");
        var attackerAuthId = Guid.NewGuid();
        await SeedStudentAsync(attackerAuthId, $"attacker-{attackerAuthId:N}@school.test");

        var response = await factory.CreateClientAs("Student", attackerAuthId)
            .PutAsJsonAsync($"/api/school/students/{victim.Id}", StudentUpdate("x@x.test", true));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Teacher_can_update_any_student()
    {
        var student = await SeedStudentAsync(Guid.NewGuid(), $"s-{Guid.NewGuid():N}@school.test");

        var response = await factory.CreateClientAs("Teacher")
            .PutAsJsonAsync($"/api/school/students/{student.Id}", StudentUpdate($"new-{Guid.NewGuid():N}@school.test", true));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Teacher_can_update_only_own_teacher_profile()
    {
        var ownAuthId = Guid.NewGuid();
        var own = new Teacher("Olim", "Karimov", ownAuthId);
        var other = new Teacher("Boshqa", "Ustoz");
        await factory.WithDbAsync(async db => { db.Teachers.AddRange(own, other); await db.SaveChangesAsync(); });
        var client = factory.CreateClientAs("Teacher", ownAuthId);
        var body = new { firstName = "Olimjon", lastName = "Karimov", isActive = false };

        var ownResponse = await client.PutAsJsonAsync($"/api/school/teachers/{own.Id}", body);
        var otherResponse = await client.PutAsJsonAsync($"/api/school/teachers/{other.Id}", body);

        Assert.Equal(HttpStatusCode.OK, ownResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, otherResponse.StatusCode);
        var saved = await factory.WithDbAsync(db => db.Teachers.AsNoTracking().SingleAsync(t => t.Id == own.Id));
        Assert.Equal("Olimjon", saved.FirstName);
        Assert.True(saved.IsActive);
    }
}
