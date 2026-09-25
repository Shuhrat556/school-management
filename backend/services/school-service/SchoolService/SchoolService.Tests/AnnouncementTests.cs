using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B21/B22: the author came from the request body, any teacher could edit
// anyone's announcement, and drafts were visible to students.
public class AnnouncementTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private async Task<(Teacher Teacher, Guid AuthId)> TeacherAsync()
    {
        var authId = Guid.NewGuid();
        var teacher = new Teacher("T", $"{Guid.NewGuid():N}"[..8], authId);
        await factory.WithDbAsync(async db => { db.Teachers.Add(teacher); await db.SaveChangesAsync(); });
        return (teacher, authId);
    }

    private static object Draft(Guid authorTeacherId, bool publish = false)
        => new { title = "Exam moved", body = "The exam is on Monday.", authorTeacherId, publishImmediately = publish };

    [Fact]
    public async Task Teacher_is_always_the_author_of_their_announcements()
    {
        var (me, myAuthId) = await TeacherAsync();
        var (someoneElse, _) = await TeacherAsync();

        var response = await factory.CreateClientAs("Teacher", myAuthId).PostAsJsonAsync("/api/announcements", Draft(someoneElse.Id));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var created = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(me.Id, created.GetProperty("authorTeacherId").GetGuid());
    }

    [Fact]
    public async Task Teacher_without_a_profile_cannot_post()
    {
        var (anyTeacher, _) = await TeacherAsync();

        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/announcements", Draft(anyTeacher.Id));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Only_the_author_or_an_admin_changes_an_announcement()
    {
        var (author, authorAuthId) = await TeacherAsync();
        var (_, otherAuthId) = await TeacherAsync();
        var created = await (await factory.CreateClientAs("Teacher", authorAuthId).PostAsJsonAsync("/api/announcements", Draft(author.Id)))
            .Content.ReadFromJsonAsync<JsonElement>();
        var id = created.GetProperty("id").GetGuid();
        var other = factory.CreateClientAs("Teacher", otherAuthId);

        Assert.Equal(HttpStatusCode.Forbidden, (await other.PutAsJsonAsync($"/api/announcements/{id}", new { title = "x", body = "y" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await other.PostAsync($"/api/announcements/{id}/publish", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await other.DeleteAsync($"/api/announcements/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await factory.CreateClientAs("Admin").PostAsync($"/api/announcements/{id}/publish", null)).StatusCode);
    }

    [Fact]
    public async Task Students_see_only_published_announcements()
    {
        var (author, authorAuthId) = await TeacherAsync();
        var teacher = factory.CreateClientAs("Teacher", authorAuthId);
        var draft = await (await teacher.PostAsJsonAsync("/api/announcements", Draft(author.Id))).Content.ReadFromJsonAsync<JsonElement>();
        var published = await (await teacher.PostAsJsonAsync("/api/announcements", Draft(author.Id, publish: true))).Content.ReadFromJsonAsync<JsonElement>();
        var student = factory.CreateClientAs("Student");

        var list = await student.GetFromJsonAsync<JsonElement>("/api/announcements");
        var ids = list.EnumerateArray().Select(a => a.GetProperty("id").GetGuid()).ToList();

        Assert.Contains(published.GetProperty("id").GetGuid(), ids);
        Assert.DoesNotContain(draft.GetProperty("id").GetGuid(), ids);
        Assert.Equal(HttpStatusCode.NotFound, (await student.GetAsync($"/api/announcements/{draft.GetProperty("id").GetGuid()}")).StatusCode);
    }
}
