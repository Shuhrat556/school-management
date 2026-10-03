using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests;

public class PasswordResetTests(AuthApiFactory factory) : IClassFixture<AuthApiFactory>
{
    private string LastCodeSentTo(string email)
    {
        lock (factory.Emails.Sent)
        {
            var mail = factory.Emails.Sent.Last(m => m.To == email);
            return Regex.Match(mail.Body, @"\b\d{6}\b").Value;
        }
    }

    [Fact]
    public async Task Reset_code_from_email_sets_a_new_password()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "OldPassword1!");
        var client = factory.CreateClient();

        await client.PostAsJsonAsync("/api/auth/request-password-reset", new { email });
        var reset = await client.PostAsJsonAsync("/api/auth/reset-password",
            new { email, code = LastCodeSentTo(email), newPassword = "NewPassword1!" });
        var login = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "NewPassword1!" });

        Assert.Equal(HttpStatusCode.OK, reset.StatusCode);
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task Wrong_codes_lock_the_reset_after_five_attempts()
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "OldPassword1!");
        var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/request-password-reset", new { email });
        var realCode = LastCodeSentTo(email);
        var wrongCode = realCode == "000000" ? "111111" : "000000";

        for (var i = 0; i < 5; i++)
            await client.PostAsJsonAsync("/api/auth/reset-password", new { email, code = wrongCode, newPassword = "NewPassword1!" });
        await client.PostAsJsonAsync("/api/auth/reset-password", new { email, code = realCode, newPassword = "NewPassword1!" });
        var login = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "NewPassword1!" });

        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
    }

    // BUGS B45: the reset accepted any new password, even a single character.
    [Theory]
    [InlineData("abc")]
    [InlineData("")]
    public async Task A_too_short_new_password_is_refused(string newPassword)
    {
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");
        var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/request-password-reset", new { email });

        var reset = await client.PostAsJsonAsync("/api/auth/reset-password",
            new { email, code = LastCodeSentTo(email), newPassword });
        var oldStillWorks = await client.PostAsJsonAsync("/api/auth/authenticate", new { email, password = "Password123!" });

        Assert.Equal(HttpStatusCode.BadRequest, reset.StatusCode);
        Assert.Equal(HttpStatusCode.OK, oldStillWorks.StatusCode);
    }

    [Fact]
    public async Task An_admin_cannot_create_an_account_with_an_oversized_password()
    {
        var adminEmail = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(adminEmail, "Password123!", AuthService.Domain.Enums.UserRole.Admin);
        var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email = adminEmail, password = "Password123!" }))
            .Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", login.GetProperty("token").GetString());

        var response = await client.PostAsJsonAsync("/api/auth/admin/users",
            new { email = AuthApiFactory.NewEmail(), firstName = "Big", lastName = "Password", password = new string('x', 5000), role = 2 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // BUGS B46: names and emails longer than the columns reached the database and failed with 500.
    [Theory]
    [InlineData(101, 10)]  // email over 100 characters
    [InlineData(20, 51)]   // last name over 50 characters
    public async Task Oversized_names_and_emails_are_a_bad_request(int emailLength, int lastNameLength)
    {
        var adminEmail = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(adminEmail, "Password123!", AuthService.Domain.Enums.UserRole.Admin);
        var client = factory.CreateClient();
        var login = await (await client.PostAsJsonAsync("/api/auth/authenticate", new { email = adminEmail, password = "Password123!" }))
            .Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", login.GetProperty("token").GetString());
        var email = new string('a', emailLength - "@school.test".Length) + "@school.test";

        var response = await client.PostAsJsonAsync("/api/auth/admin/users",
            new { email, firstName = "Ali", lastName = new string('b', lastNameLength), password = "Password123!", role = 2 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
