using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F7: homework is a class material of type Assignment with an optional due date; the teacher
// sees how many students handed it in. BUGS B35: deleting a material erased students' work.
public class HomeworkTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid ClassroomId, Guid StudentAuthId);

    private async Task<World> SeedAsync()
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Home", "Worker", studentAuthId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Guid classroomId = default;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Biology {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var classroom = new Classroom($"BI-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
            classroomId = classroom.Id;
        });
        return new World(classroomId, studentAuthId);
    }

    private async Task<Guid> AssignAsync(World w, string? dueAt = "2026-10-20T18:00:00Z")
    {
        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/materials",
            new { classroomId = w.ClassroomId, title = "Cells worksheet", description = "Pages 10-12", type = 2, dueAt });
        Assert.True(response.IsSuccessStatusCode, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
    }

    private static async Task<JsonElement[]> ListAsync(HttpClient client, World w)
        => (await client.GetFromJsonAsync<JsonElement>($"/api/materials/classroom/{w.ClassroomId}")).EnumerateArray().ToArray();

    [Fact]
    public async Task Homework_keeps_its_due_date_and_counts_students_who_handed_it_in()
    {
        var w = await SeedAsync();
        var homeworkId = await AssignAsync(w);
        var student = factory.CreateClientAs("Student", w.StudentAuthId);
        await student.PostAsJsonAsync("/api/submissions", new { materialId = homeworkId, submissionUrl = "draft.pdf" });
        await student.PostAsJsonAsync("/api/submissions", new { materialId = homeworkId, submissionUrl = "final.pdf" });

        var homework = Assert.Single(await ListAsync(factory.CreateClientAs("Teacher"), w));

        Assert.Equal(new DateTime(2026, 10, 20, 18, 0, 0, DateTimeKind.Utc), homework.GetProperty("dueAt").GetDateTime().ToUniversalTime());
        Assert.Equal(1, homework.GetProperty("submissionCount").GetInt32());
        Assert.Equal(2, homework.GetProperty("type").GetInt32());
    }

    [Fact]
    public async Task Homework_without_a_due_date_is_allowed()
    {
        var w = await SeedAsync();
        await AssignAsync(w, dueAt: null);

        var homework = Assert.Single(await ListAsync(factory.CreateClientAs("Teacher"), w));

        Assert.Equal(JsonValueKind.Null, homework.GetProperty("dueAt").ValueKind);
    }

    [Fact]
    public async Task Deleting_homework_keeps_the_students_work()
    {
        var w = await SeedAsync();
        var homeworkId = await AssignAsync(w);
        await factory.CreateClientAs("Student", w.StudentAuthId).PostAsJsonAsync("/api/submissions",
            new { materialId = homeworkId, submissionUrl = "final.pdf" });

        var delete = await factory.CreateClientAs("Teacher").DeleteAsync($"/api/materials/{homeworkId}");

        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Empty(await ListAsync(factory.CreateClientAs("Teacher"), w));
        Assert.Equal(1, await factory.WithDbAsync(db => db.Submissions.CountAsync(s => s.MaterialId == homeworkId)));
    }

    [Fact]
    public async Task Inactive_homework_is_hidden_from_students_but_not_from_teachers()
    {
        var w = await SeedAsync();
        var homeworkId = await AssignAsync(w);
        await factory.CreateClientAs("Teacher").PutAsJsonAsync($"/api/materials/{homeworkId}",
            new { title = "Cells worksheet", type = 2, isActive = false });

        Assert.Empty(await ListAsync(factory.CreateClientAs("Student", w.StudentAuthId), w));
        Assert.Single(await ListAsync(factory.CreateClientAs("Teacher"), w));
    }

    [Fact]
    public async Task Homework_for_an_unknown_class_is_not_found()
    {
        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/materials",
            new { classroomId = Guid.NewGuid(), title = "Lost", type = 2 });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
