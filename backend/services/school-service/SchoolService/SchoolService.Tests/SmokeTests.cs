using System.Net;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

public class SmokeTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    [Fact]
    public async Task Health_is_public()
    {
        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Api_requires_a_token()
    {
        var response = await factory.CreateClient().GetAsync("/api/school/subjects");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Signed_in_user_can_list_subjects()
    {
        var response = await factory.CreateClientAs("Teacher").GetAsync("/api/school/subjects");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
