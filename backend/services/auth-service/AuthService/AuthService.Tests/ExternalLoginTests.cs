using System.Net;
using System.Net.Http.Json;
using AuthService.Application.Interfaces;
using AuthService.Domain.Enums;
using AuthService.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace AuthService.Tests;

// BUGS B4: a Facebook login whose (unverified) email matched an existing
// account was linked to that account and signed in as its owner.
public class ExternalLoginTests
{
    // Tokens look like "<provider>|<providerUserId>|<email>|<verified>".
    private sealed class FakeExternalAuthValidator : IExternalAuthValidator
    {
        public Task<ExternalAuthIdentity> ValidateGoogleIdTokenAsync(string idToken) => Parse(ExternalAuthProvider.Google, idToken);
        public Task<ExternalAuthIdentity> ValidateFacebookAccessTokenAsync(string accessToken) => Parse(ExternalAuthProvider.Facebook, accessToken);

        private static Task<ExternalAuthIdentity> Parse(ExternalAuthProvider provider, string token)
        {
            var parts = token.Split('|');
            return Task.FromResult(new ExternalAuthIdentity(provider, parts[0], parts[1], bool.Parse(parts[2]), "Someone"));
        }
    }

    private sealed class OAuthFactory : AuthApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IExternalAuthValidator>();
                services.AddScoped<IExternalAuthValidator, FakeExternalAuthValidator>();
            });
        }
    }

    [Fact]
    public async Task Facebook_email_does_not_take_over_an_existing_account()
    {
        using var factory = new OAuthFactory();
        var victim = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(victim, "Password123!", UserRole.Admin);

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/facebook",
            new { accessToken = $"fb-attacker|{victim}|false" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Google_verified_email_signs_in_the_matching_account()
    {
        using var factory = new OAuthFactory();
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/google",
            new { idToken = $"g-123|{email}|true" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Unverified_google_email_is_not_linked()
    {
        using var factory = new OAuthFactory();
        var email = AuthApiFactory.NewEmail();
        await factory.CreateUserAsync(email, "Password123!");

        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/oauth/google",
            new { idToken = $"g-456|{email}|false" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
