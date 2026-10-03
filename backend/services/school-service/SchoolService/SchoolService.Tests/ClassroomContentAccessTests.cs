using System.Net;
using System.Net.Http.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B31: any signed-in user could read any class's materials and hand in work for
// classes they are not in; links were stored with any scheme (javascript: etc.).
public class ClassroomContentAccessTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid ClassroomId, Guid MaterialId, Guid MemberAuthId, Guid OutsiderAuthId, Guid MemberId);

    private async Task<World> SeedAsync()
    {
        var memberAuthId = Guid.NewGuid();
        var outsiderAuthId = Guid.NewGuid();
        var member = new Student("Class", "Member", memberAuthId);
        var outsider = new Student("Class", "Outsider", outsiderAuthId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Guid classroomId = default, materialId = default;
        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(member, outsider);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Literature {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var classroom = new Classroom($"LI-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            var material = new Material(classroom.Id, "Essay", MaterialType.Assignment);
            db.Materials.Add(material);
            db.StudentClassrooms.Add(new StudentClassroom(member.Id, classroom.Id));
            await db.SaveChangesAsync();
            classroomId = classroom.Id;
            materialId = material.Id;
        });
        return new World(classroomId, materialId, memberAuthId, outsiderAuthId, member.Id);
    }

    [Fact]
    public async Task A_student_outside_the_class_cannot_read_its_materials()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.OutsiderAuthId).GetAsync($"/api/materials/classroom/{w.ClassroomId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task A_parent_of_a_member_reads_the_materials()
    {
        var w = await SeedAsync();
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{w.MemberId}/parents",
            new { parentAuthUserId = parentId, fullName = "Member Parent" });

        var response = await factory.CreateClientAs("Parent", parentId).GetAsync($"/api/materials/classroom/{w.ClassroomId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task A_student_outside_the_class_cannot_hand_in_work()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.OutsiderAuthId).PostAsJsonAsync("/api/submissions",
            new { materialId = w.MaterialId, submissionUrl = "https://drive.example.com/essay" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("javascript:alert(document.cookie)")]
    [InlineData("data:text/html;base64,PHNjcmlwdD4=")]
    [InlineData(" JavaScript:alert(1)")]
    public async Task Links_with_unsafe_schemes_are_rejected(string link)
    {
        var w = await SeedAsync();

        var submission = await factory.CreateClientAs("Student", w.MemberAuthId).PostAsJsonAsync("/api/submissions",
            new { materialId = w.MaterialId, submissionUrl = link });
        var material = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/materials",
            new { classroomId = w.ClassroomId, title = "Reading", type = 1, url = link });

        Assert.Equal(HttpStatusCode.BadRequest, submission.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, material.StatusCode);
    }

    [Theory]
    [InlineData("https://drive.example.com/essay")]
    [InlineData("essay-final.pdf")]
    public async Task Web_links_and_plain_file_references_are_accepted(string link)
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.MemberAuthId).PostAsJsonAsync("/api/submissions",
            new { materialId = w.MaterialId, submissionUrl = link });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
