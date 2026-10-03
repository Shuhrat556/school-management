using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B32: students and parents saw the announcements of every class, not just their own.
public class AnnouncementVisibilityTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid StudentAuthId, Guid StudentId, Guid MyClass, Guid OtherClass, string Tag);

    private async Task<World> SeedAsync()
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Ann", "Reader", studentAuthId);
        var teacher = new Teacher("Ann", "Author");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Classroom mine = null!, other = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Teachers.Add(teacher);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Music {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            mine = new Classroom($"MY-{Guid.NewGuid():N}", subject.Id);
            other = new Classroom($"OT-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.AddRange(mine, other);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, mine.Id));
            await db.SaveChangesAsync();
        });

        var tag = Guid.NewGuid().ToString("N")[..8];
        var admin = factory.CreateClientAs("Admin");
        foreach (var (title, classroomId) in new (string, Guid?)[] { ($"School {tag}", null), ($"Mine {tag}", mine.Id), ($"Other {tag}", other.Id) })
        {
            var created = await admin.PostAsJsonAsync("/api/announcements",
                new { title, body = "text", authorTeacherId = teacher.Id, classroomId, publishImmediately = true });
            Assert.True(created.IsSuccessStatusCode, await created.Content.ReadAsStringAsync());
        }
        return new World(studentAuthId, student.Id, mine.Id, other.Id, tag);
    }

    private static async Task<string[]> TitlesAsync(HttpClient client, string tag, string query = "")
        => (await client.GetFromJsonAsync<JsonElement>($"/api/announcements{query}")).EnumerateArray()
            .Select(a => a.GetProperty("title").GetString()!).Where(t => t.EndsWith(tag)).OrderBy(t => t).ToArray();

    [Fact]
    public async Task A_student_sees_school_wide_and_own_class_announcements_only()
    {
        var w = await SeedAsync();

        var titles = await TitlesAsync(factory.CreateClientAs("Student", w.StudentAuthId), w.Tag);

        Assert.Equal([$"Mine {w.Tag}", $"School {w.Tag}"], titles);
    }

    [Fact]
    public async Task A_student_cannot_ask_for_another_class()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.StudentAuthId).GetAsync($"/api/announcements?classroomId={w.OtherClass}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Another_class_announcement_is_not_found_for_a_student()
    {
        var w = await SeedAsync();
        var all = await factory.CreateClientAs("Admin").GetFromJsonAsync<JsonElement>("/api/announcements");
        var otherId = all.EnumerateArray().First(a => a.GetProperty("title").GetString() == $"Other {w.Tag}").GetProperty("id").GetGuid();

        var response = await factory.CreateClientAs("Student", w.StudentAuthId).GetAsync($"/api/announcements/{otherId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task A_parent_sees_the_child_class_announcements()
    {
        var w = await SeedAsync();
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{w.StudentId}/parents",
            new { parentAuthUserId = parentId, fullName = "Ann Parent" });

        var titles = await TitlesAsync(factory.CreateClientAs("Parent", parentId), w.Tag);

        Assert.Equal([$"Mine {w.Tag}", $"School {w.Tag}"], titles);
    }

    [Fact]
    public async Task Staff_see_every_class()
    {
        var w = await SeedAsync();

        Assert.Equal(3, (await TitlesAsync(factory.CreateClientAs("Teacher"), w.Tag)).Length);
    }
}
