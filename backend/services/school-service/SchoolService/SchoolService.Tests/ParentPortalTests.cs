using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F1: a parent account sees the children an admin linked to it, and nobody else.
public class ParentPortalTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record Family(Guid ParentId, Student Child, Student Stranger);

    private async Task<Family> SeedAsync(bool link = true)
    {
        var child = new Student("Child", "One");
        var stranger = new Student("Other", "Kid");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(child, stranger);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Bio {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            db.StudentGrades.AddRange(new StudentGrade(child.Id, subject.Id, 88, "1"), new StudentGrade(stranger.Id, subject.Id, 40, "1"));
            db.Attendances.Add(new Attendance(child.Id, null, new DateOnly(2026, 9, 2), AttendanceStatus.Late));
            await db.SaveChangesAsync();
        });

        var parentId = Guid.NewGuid();
        if (link)
        {
            var response = await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{child.Id}/parents",
                new { parentAuthUserId = parentId, fullName = "Dilnoza Karimova", email = "parent@school.test", relationship = "Mother" });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
        return new Family(parentId, child, stranger);
    }

    [Fact]
    public async Task Parent_lists_linked_children()
    {
        var f = await SeedAsync();

        var children = await factory.CreateClientAs("Parent", f.ParentId).GetFromJsonAsync<JsonElement>("/api/school/parents/me/children");

        Assert.Equal(f.Child.Id, Assert.Single(children.EnumerateArray()).GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task Parent_reads_childs_grades_and_attendance()
    {
        var f = await SeedAsync();
        var parent = factory.CreateClientAs("Parent", f.ParentId);

        var grades = await parent.GetFromJsonAsync<JsonElement>($"/api/school/grades?studentId={f.Child.Id}");
        var attendance = await parent.GetAsync($"/api/school/attendance/{f.Child.Id}/history");
        var profile = await parent.GetAsync($"/api/school/students/{f.Child.Id}");

        Assert.Equal(88m, Assert.Single(grades.EnumerateArray()).GetProperty("score").GetDecimal());
        Assert.Equal(HttpStatusCode.OK, attendance.StatusCode);
        Assert.Equal(HttpStatusCode.OK, profile.StatusCode);
    }

    [Fact]
    public async Task Parent_cannot_read_other_children()
    {
        var f = await SeedAsync();
        var parent = factory.CreateClientAs("Parent", f.ParentId);

        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync($"/api/school/grades?studentId={f.Stranger.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync("/api/school/grades")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync($"/api/school/students/{f.Stranger.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync("/api/school/students")).StatusCode);
    }

    [Fact]
    public async Task Unlinked_parent_sees_nothing()
    {
        var f = await SeedAsync(link: false);
        var parent = factory.CreateClientAs("Parent", f.ParentId);

        var children = await parent.GetFromJsonAsync<JsonElement>("/api/school/parents/me/children");

        Assert.Empty(children.EnumerateArray());
        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync($"/api/school/grades?studentId={f.Child.Id}")).StatusCode);
    }

    [Fact]
    public async Task Only_admins_link_parents_and_unlinking_revokes_access()
    {
        var f = await SeedAsync();
        var body = new { parentAuthUserId = Guid.NewGuid(), fullName = "Someone" };

        var byTeacher = await factory.CreateClientAs("Teacher").PostAsJsonAsync($"/api/school/students/{f.Child.Id}/parents", body);
        var byParent = await factory.CreateClientAs("Parent", f.ParentId).PostAsJsonAsync($"/api/school/students/{f.Stranger.Id}/parents",
            new { parentAuthUserId = f.ParentId, fullName = "Me" });
        var listed = await factory.CreateClientAs("Teacher").GetFromJsonAsync<JsonElement>($"/api/school/students/{f.Child.Id}/parents");
        var unlink = await factory.CreateClientAs("Admin").DeleteAsync($"/api/school/students/{f.Child.Id}/parents/{f.ParentId}");
        var after = await factory.CreateClientAs("Parent", f.ParentId).GetAsync($"/api/school/students/{f.Child.Id}");

        Assert.Equal(HttpStatusCode.Forbidden, byTeacher.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byParent.StatusCode);
        Assert.Equal("Mother", Assert.Single(listed.EnumerateArray()).GetProperty("relationship").GetString());
        Assert.Equal(HttpStatusCode.NoContent, unlink.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, after.StatusCode);
    }

    [Fact]
    public async Task Linking_again_updates_details_instead_of_duplicating()
    {
        var f = await SeedAsync();
        var admin = factory.CreateClientAs("Admin");

        await admin.PostAsJsonAsync($"/api/school/students/{f.Child.Id}/parents",
            new { parentAuthUserId = f.ParentId, fullName = "Dilnoza Karimova", relationship = "Guardian" });
        var parents = await admin.GetFromJsonAsync<JsonElement>($"/api/school/students/{f.Child.Id}/parents");

        Assert.Equal("Guardian", Assert.Single(parents.EnumerateArray()).GetProperty("relationship").GetString());
    }
}
