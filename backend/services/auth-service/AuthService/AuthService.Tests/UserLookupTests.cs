using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Domain.Enums;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests;

// BUGS B29: any signed-in user could read another account's email and role.
public class UserLookupTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private async Task<(HttpClient Client, Guid UserId)> SignInAsync(UserRole role)
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, "Password123!", role);
        var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login.GetProperty("token").GetString());
        return (client, user.Id);
    }

    [Fact]
    public async Task A_student_cannot_look_up_someone_else()
    {
        var (student, _) = await SignInAsync(UserRole.Student);
        var (_, otherId) = await SignInAsync(UserRole.Teacher);

        var response = await student.GetAsync($"/api/auth/user/{otherId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Users_see_themselves_and_admins_see_everyone()
    {
        var (student, studentId) = await SignInAsync(UserRole.Student);
        var (admin, _) = await SignInAsync(UserRole.Admin);

        Assert.Equal(HttpStatusCode.OK, (await student.GetAsync($"/api/auth/user/{studentId}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync($"/api/auth/user/{studentId}")).StatusCode);
    }

    [Fact]
    public async Task A_malformed_id_is_a_bad_request()
    {
        var (admin, _) = await SignInAsync(UserRole.Admin);

        var response = await admin.GetAsync("/api/auth/user/not-a-guid");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
