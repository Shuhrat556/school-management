using Microsoft.AspNetCore.Hosting;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B2: without JWT_SECRET the service accepted tokens signed with a key
// that is published in the repository.
public class JwtSecretStartupTests
{
    private sealed class ProductionFactory(string secret) : SchoolApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.UseEnvironment("Production");
            builder.UseSetting("Jwt:Secret", secret);
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("too-short-secret")]
    [InlineData("your-secret-key-change-me-in-production-this-is-insecure")]
    public void Production_refuses_to_start_without_a_strong_secret(string secret)
    {
        using var factory = new ProductionFactory(secret);

        var error = Assert.ThrowsAny<Exception>(() => factory.CreateClient());

        Assert.Contains("Jwt:Secret", error.GetBaseException().Message);
    }

    [Fact]
    public void Production_starts_with_a_strong_secret()
    {
        using var factory = new ProductionFactory(TestTokens.Secret);

        using var client = factory.CreateClient();
    }
}
