using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F8: a student (or their parent) asks to be excused; staff approve or reject it and the
// family is notified. BUGS B38: the app only kept the request on the phone.
public class LeaveRequestTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid StudentId, Guid StudentAuthId, Guid ParentId);

    private async Task<World> SeedAsync()
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Leave", "Asker", studentAuthId);
        await factory.WithDbAsync(async db => { db.Students.Add(student); await db.SaveChangesAsync(); });
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{student.Id}/parents",
            new { parentAuthUserId = parentId, fullName = "Leave Parent" });
        return new World(student.Id, studentAuthId, parentId);
    }

    private static object Request(Guid? studentId = null, string start = "2026-10-12", string? end = null, string reason = "Fever, doctor's note attached")
        => new { studentId, type = 1, startDate = start, endDate = end, reason };

    private static async Task<JsonElement> FileAsync(HttpClient client, object body)
    {
        var response = await client.PostAsJsonAsync("/api/school/leave-requests", body);
        Assert.True(response.StatusCode == HttpStatusCode.Created, await response.Content.ReadAsStringAsync());
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private static async Task<JsonElement[]> MineAsync(HttpClient client)
        => (await client.GetFromJsonAsync<JsonElement>("/api/school/leave-requests/mine")).EnumerateArray().ToArray();

    [Fact]
    public async Task A_student_asks_and_a_teacher_approves()
    {
        var w = await SeedAsync();
        var student = factory.CreateClientAs("Student", w.StudentAuthId);
        var created = await FileAsync(student, Request(end: "2026-10-14"));
        Assert.Equal("Pending", created.GetProperty("status").GetString());

        var pending = await factory.CreateClientAs("Teacher").GetFromJsonAsync<JsonElement>($"/api/school/leave-requests?status=Pending&studentId={w.StudentId}");
        var approve = await factory.CreateClientAs("Teacher").PostAsJsonAsync(
            $"/api/school/leave-requests/{created.GetProperty("id").GetGuid()}/approve", new { note = "Get well soon" });

        Assert.Single(pending.EnumerateArray());
        Assert.Equal(HttpStatusCode.OK, approve.StatusCode);
        var mine = Assert.Single(await MineAsync(student));
        Assert.Equal("Approved", mine.GetProperty("status").GetString());
        Assert.Equal("Get well soon", mine.GetProperty("reviewNote").GetString());
        Assert.Equal("2026-10-14", mine.GetProperty("endDate").GetString());
        Assert.Equal("Sick", mine.GetProperty("type").GetString());
    }

    [Fact]
    public async Task The_family_hears_about_the_decision()
    {
        var w = await SeedAsync();
        var created = await FileAsync(factory.CreateClientAs("Student", w.StudentAuthId), Request());

        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/leave-requests/{created.GetProperty("id").GetGuid()}/reject",
            new { note = "Exam day" });

        var feed = (await factory.CreateClientAs("Parent", w.ParentId).GetFromJsonAsync<JsonElement>("/api/school/notifications")).EnumerateArray();
        Assert.Contains(feed, n => n.GetProperty("title").GetString() == "Leave request rejected");
    }

    [Fact]
    public async Task A_parent_asks_for_their_child_only()
    {
        var w = await SeedAsync();
        var parent = factory.CreateClientAs("Parent", w.ParentId);

        var own = await parent.PostAsJsonAsync("/api/school/leave-requests", Request(w.StudentId));
        var stranger = await parent.PostAsJsonAsync("/api/school/leave-requests", Request(Guid.NewGuid()));

        Assert.Equal(HttpStatusCode.Created, own.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, stranger.StatusCode);
        Assert.Single(await MineAsync(parent));
    }

    [Fact]
    public async Task Students_see_only_their_own_requests_and_cannot_decide()
    {
        var w = await SeedAsync();
        var other = await SeedAsync();
        var created = await FileAsync(factory.CreateClientAs("Student", other.StudentAuthId), Request());
        var student = factory.CreateClientAs("Student", w.StudentAuthId);

        var approve = await student.PostAsJsonAsync($"/api/school/leave-requests/{created.GetProperty("id").GetGuid()}/approve", new { });
        var staffList = await student.GetAsync("/api/school/leave-requests");

        Assert.Empty(await MineAsync(student));
        Assert.Equal(HttpStatusCode.Forbidden, approve.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, staffList.StatusCode);
    }

    [Fact]
    public async Task A_request_is_decided_once()
    {
        var w = await SeedAsync();
        var created = await FileAsync(factory.CreateClientAs("Student", w.StudentAuthId), Request());
        var teacher = factory.CreateClientAs("Teacher");
        var url = $"/api/school/leave-requests/{created.GetProperty("id").GetGuid()}";

        await teacher.PostAsJsonAsync($"{url}/approve", new { });
        var again = await teacher.PostAsJsonAsync($"{url}/reject", new { });

        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Theory]
    [InlineData("2026-10-12", "2026-10-10", "Fever")] // ends before it starts
    [InlineData("2026-10-12", null, "")]               // no reason
    public async Task Invalid_requests_are_rejected(string start, string? end, string reason)
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.StudentAuthId).PostAsJsonAsync("/api/school/leave-requests",
            Request(start: start, end: end, reason: reason));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
