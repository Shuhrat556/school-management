using AuthService.Application.Interfaces;
using AuthService.Domain.Enums;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace AuthService.Tests.Infrastructure;

// Tokens look like "<providerUserId>|<email>|<verified>".
public sealed class FakeExternalAuthValidator : IExternalAuthValidator
{
    public Task<ExternalAuthIdentity> ValidateGoogleIdTokenAsync(string idToken) => Parse(ExternalAuthProvider.Google, idToken);
    public Task<ExternalAuthIdentity> ValidateFacebookAccessTokenAsync(string accessToken) => Parse(ExternalAuthProvider.Facebook, accessToken);

    private static Task<ExternalAuthIdentity> Parse(ExternalAuthProvider provider, string token)
    {
        var parts = token.Split('|');
        return Task.FromResult(new ExternalAuthIdentity(provider, parts[0], parts[1], bool.Parse(parts[2]), "Someone"));
    }
}

// The real API with Google/Facebook token checks replaced by FakeExternalAuthValidator.
public sealed class OAuthFactory : AuthApiFactory
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
