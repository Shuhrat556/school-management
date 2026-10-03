using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B43: any signed-in student could open any class and read every classmate's
// email, phone and date of birth; the class list showed every class in the school.
public class ClassroomPrivacyTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid MyClass, Guid OtherClass, Guid StudentAuthId, Guid StudentId);

    private async Task<World> SeedAsync()
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Private", "Me", studentAuthId);
        var classmate = new Student("Class", "Mate");
        classmate.UpdateBasicInfo("Class", "Mate", "F", new DateTime(2012, 5, 1, 0, 0, 0, DateTimeKind.Utc), "+998901112233", "Tashkent", $"mate{Guid.NewGuid():N}@school.test");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Classroom mine = null!, other = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(student, classmate);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Art {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            mine = new Classroom($"MINE-{Guid.NewGuid():N}", subject.Id);
            other = new Classroom($"OTHER-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.AddRange(mine, other);
            await db.SaveChangesAsync();
            db.StudentClassrooms.AddRange(
                new StudentClassroom(student.Id, mine.Id),
                new StudentClassroom(classmate.Id, mine.Id),
                new StudentClassroom(classmate.Id, other.Id));
            await db.SaveChangesAsync();
        });
        return new World(mine.Id, other.Id, studentAuthId, student.Id);
    }

    [Fact]
    public async Task A_student_cannot_open_a_class_they_are_not_in()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Student", w.StudentAuthId).GetAsync($"/api/school/classrooms/{w.OtherClass}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Classmates_are_listed_without_contact_details()
    {
        var w = await SeedAsync();

        var detail = await factory.CreateClientAs("Student", w.StudentAuthId).GetFromJsonAsync<JsonElement>($"/api/school/classrooms/{w.MyClass}");

        var mate = detail.GetProperty("students").EnumerateArray().Single(s => s.GetProperty("firstName").GetString() == "Class");
        Assert.Equal(JsonValueKind.Null, mate.GetProperty("email").ValueKind);
        Assert.Equal(JsonValueKind.Null, mate.GetProperty("phone").ValueKind);
        Assert.Equal(JsonValueKind.Null, mate.GetProperty("dateOfBirth").ValueKind);
    }

    [Fact]
    public async Task Staff_still_see_contact_details()
    {
        var w = await SeedAsync();

        var detail = await factory.CreateClientAs("Teacher").GetFromJsonAsync<JsonElement>($"/api/school/classrooms/{w.MyClass}");

        var mate = detail.GetProperty("students").EnumerateArray().Single(s => s.GetProperty("firstName").GetString() == "Class");
        Assert.Equal("+998901112233", mate.GetProperty("phone").GetString());
    }

    [Fact]
    public async Task A_student_lists_only_their_own_classes()
    {
        var w = await SeedAsync();

        var list = await factory.CreateClientAs("Student", w.StudentAuthId).GetFromJsonAsync<JsonElement>("/api/school/classrooms");

        var ids = list.EnumerateArray().Select(c => c.GetProperty("id").GetGuid()).ToList();
        Assert.Contains(w.MyClass, ids);
        Assert.DoesNotContain(w.OtherClass, ids);
    }

    [Fact]
    public async Task A_parent_opens_their_child_class()
    {
        var w = await SeedAsync();
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{w.StudentId}/parents",
            new { parentAuthUserId = parentId, fullName = "Private Parent" });

        var parent = factory.CreateClientAs("Parent", parentId);

        Assert.Equal(HttpStatusCode.OK, (await parent.GetAsync($"/api/school/classrooms/{w.MyClass}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await parent.GetAsync($"/api/school/classrooms/{w.OtherClass}")).StatusCode);
    }
}
