using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests;

// BUGS B28: changing the password was meant to end every other session, but the
// user was loaded without their refresh tokens, so none were revoked.
public class ChangePasswordTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private static async Task<JsonElement> LoginAsync(HttpClient client, string email, string password)
    {
        var response = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    [Fact]
    public async Task Changing_the_password_signs_out_other_sessions()
    {
        var email = AuthApiFactory.NewEmail();
        var user = await factory.CreateUserAsync(email, "Password123!");
        var laptop = factory.CreateClient();
        var phone = factory.CreateClient();
        var laptopSession = await LoginAsync(laptop, email, "Password123!");
        var phoneSession = await LoginAsync(phone, email, "Password123!");

        laptop.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", laptopSession.GetProperty("token").GetString());
        var change = await laptop.PostAsJsonAsync("/api/auth/change-password",
            new { userId = user.Id, currentPassword = "Password123!", newPassword = "NewPassword456!" });

        Assert.Equal(HttpStatusCode.OK, change.StatusCode);
        var phoneRefresh = await phone.PostAsJsonAsync("/api/auth/refresh",
            new { refreshToken = phoneSession.GetProperty("refreshToken").GetString() });
        Assert.Equal(HttpStatusCode.Unauthorized, phoneRefresh.StatusCode);
        await LoginAsync(phone, email, "NewPassword456!");
    }
}
