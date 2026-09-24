using System.Net;
using System.Net.Http.Json;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B1: every signed-in user could call every write endpoint.
public class RoleAuthorizationTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private static readonly string Id = Guid.NewGuid().ToString();
    private static readonly string Id2 = Guid.NewGuid().ToString();

    // Endpoints that only staff (Admin, Teacher) may call.
    public static TheoryData<string, string> StaffOnly => new()
    {
        { "POST", "/api/school/students" },
        { "POST", "/api/school/subjects" },
        { "POST", $"/api/school/subjects/{Id}/assign-teacher" },
        { "POST", "/api/school/classrooms" },
        { "PUT", $"/api/school/classrooms/{Id}" },
        { "POST", $"/api/school/classrooms/{Id}/enroll" },
        { "DELETE", $"/api/school/classrooms/{Id}/unenroll/{Id2}" },
        { "POST", "/api/school/schedules" },
        { "PUT", $"/api/school/schedules/{Id}" },
        { "DELETE", $"/api/school/schedules/{Id}" },
        { "GET", $"/api/school/attendance?classroomId={Id}&date=2026-09-01" },
        { "POST", "/api/school/attendance/mark" },
        { "POST", "/api/school/grades" },
        { "PUT", $"/api/school/grades/{Id}" },
        { "DELETE", $"/api/school/grades/{Id}" },
        { "POST", "/api/announcements" },
        { "PUT", $"/api/announcements/{Id}" },
        { "POST", $"/api/announcements/{Id}/publish" },
        { "POST", $"/api/announcements/{Id}/unpublish" },
        { "DELETE", $"/api/announcements/{Id}" },
        { "POST", "/api/materials" },
        { "PUT", $"/api/materials/{Id}" },
        { "DELETE", $"/api/materials/{Id}" },
        { "GET", $"/api/submissions/material/{Id}" },
        { "PATCH", $"/api/submissions/{Id}/grade" },
    };

    // Endpoints that only an Admin may call.
    public static TheoryData<string, string> AdminOnly => new()
    {
        { "DELETE", $"/api/school/students/{Id}" },
        { "POST", "/api/school/teachers" },
        { "DELETE", $"/api/school/teachers/{Id}" },
        { "PUT", $"/api/school/subjects/{Id}" },
        { "DELETE", $"/api/school/subjects/{Id}" },
        { "DELETE", $"/api/school/subjects/{Id}/remove-teacher/{Id2}" },
        { "DELETE", $"/api/school/classrooms/{Id}" },
    };

    [Theory]
    [MemberData(nameof(StaffOnly))]
    [MemberData(nameof(AdminOnly))]
    public async Task Student_is_forbidden(string method, string path)
    {
        var response = await Send(factory.CreateClientAs("Student"), method, path);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(AdminOnly))]
    public async Task Teacher_is_forbidden_on_admin_endpoints(string method, string path)
    {
        var response = await Send(factory.CreateClientAs("Teacher"), method, path);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(StaffOnly))]
    public async Task Teacher_passes_the_role_check_on_staff_endpoints(string method, string path)
    {
        var response = await Send(factory.CreateClientAs("Teacher"), method, path);

        Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [MemberData(nameof(AdminOnly))]
    public async Task Admin_passes_the_role_check_on_admin_endpoints(string method, string path)
    {
        var response = await Send(factory.CreateClientAs("Admin"), method, path);

        Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static Task<HttpResponseMessage> Send(HttpClient client, string method, string path)
    {
        var request = new HttpRequestMessage(new HttpMethod(method), path);
        if (method is "POST" or "PUT" or "PATCH")
            request.Content = JsonContent.Create(new { });
        return client.SendAsync(request);
    }
}
