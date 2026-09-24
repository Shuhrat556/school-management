using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B9: the materials and submissions controllers asked DI for concrete
// services that were never registered, so every call failed with 500.
public class MaterialsAndSubmissionsTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record Seeded(Guid ClassroomId, Guid MaterialId, Student Me, Guid MyAuthId, Student Other);

    private async Task<Seeded> SeedAsync()
    {
        var myAuthId = Guid.NewGuid();
        var me = new Student("Me", "Student", myAuthId);
        var other = new Student("Other", "Student", Guid.NewGuid());
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Guid classroomId = default, materialId = default;

        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(me, other);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"CS {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var classroom = new Classroom($"CS-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            var material = new Material(classroom.Id, "Homework 1", MaterialType.Assignment, description: "Solve 1-10");
            db.Materials.Add(material);
            await db.SaveChangesAsync();
            classroomId = classroom.Id;
            materialId = material.Id;
        });

        return new Seeded(classroomId, materialId, me, myAuthId, other);
    }

    [Fact]
    public async Task Materials_of_a_classroom_can_be_listed()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Student", s.MyAuthId).GetAsync($"/api/materials/classroom/{s.ClassroomId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var items = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Single(items.EnumerateArray());
    }

    [Fact]
    public async Task Teacher_can_create_material()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/materials",
            new { classroomId = s.ClassroomId, title = "Slides week 2", type = (int)MaterialType.Slide });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Student_submits_own_work_and_teacher_grades_it()
    {
        var s = await SeedAsync();
        var student = factory.CreateClientAs("Student", s.MyAuthId);

        var submit = await student.PostAsJsonAsync("/api/submissions",
            new { materialId = s.MaterialId, submissionUrl = "https://drive.example/hw1" });

        Assert.Equal(HttpStatusCode.OK, submit.StatusCode);
        var created = await submit.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(s.Me.Id, created.GetProperty("studentId").GetGuid());

        var grade = await factory.CreateClientAs("Teacher").PatchAsJsonAsync(
            $"/api/submissions/{created.GetProperty("id").GetGuid()}/grade", new { grade = 88, feedback = "Good" });
        Assert.Equal(HttpStatusCode.NoContent, grade.StatusCode);

        var mine = await student.GetFromJsonAsync<JsonElement>($"/api/submissions/student/{s.Me.Id}");
        Assert.Equal(88m, mine.EnumerateArray().Single().GetProperty("grade").GetDecimal());
    }

    [Fact]
    public async Task Legacy_submit_route_accepts_only_own_student_id()
    {
        var s = await SeedAsync();
        var student = factory.CreateClientAs("Student", s.MyAuthId);
        var body = new { materialId = s.MaterialId, submissionUrl = "https://drive.example/x" };

        var own = await student.PostAsJsonAsync($"/api/submissions/{s.Me.Id}/submit", body);
        var impersonated = await student.PostAsJsonAsync($"/api/submissions/{s.Other.Id}/submit", body);

        Assert.Equal(HttpStatusCode.OK, own.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, impersonated.StatusCode);
    }

    [Fact]
    public async Task Student_cannot_read_another_students_submissions()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Student", s.MyAuthId).GetAsync($"/api/submissions/student/{s.Other.Id}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Submitting_to_unknown_material_is_404()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Student", s.MyAuthId).PostAsJsonAsync("/api/submissions",
            new { materialId = Guid.NewGuid(), submissionUrl = "https://drive.example/x" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task User_without_a_student_profile_cannot_submit()
    {
        var s = await SeedAsync();

        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/submissions",
            new { materialId = s.MaterialId, submissionUrl = "https://drive.example/x" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
