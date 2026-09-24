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
}
