using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B23: an unenrolled student stayed on the class roster and could never be enrolled again.
public class EnrollmentTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private async Task<(Student Student, Classroom Classroom)> SeedAsync()
    {
        var student = new Student("Roster", "Student");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Classroom classroom = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Geography {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            classroom = new Classroom($"GE-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
        });
        return (student, classroom);
    }

    private static Task<HttpResponseMessage> EnrollAsync(HttpClient client, Classroom classroom, Student student)
        => client.PostAsJsonAsync($"/api/school/classrooms/{classroom.Id}/enroll", new { studentId = student.Id });

    private static Task<HttpResponseMessage> UnenrollAsync(HttpClient client, Classroom classroom, Student student)
        => client.DeleteAsync($"/api/school/classrooms/{classroom.Id}/unenroll/{student.Id}");

    private static async Task<JsonElement[]> RosterAsync(HttpClient client, Classroom classroom)
        => (await client.GetFromJsonAsync<JsonElement>($"/api/school/classrooms/{classroom.Id}"))
            .GetProperty("students").EnumerateArray().ToArray();

    [Fact]
    public async Task Unenrolled_student_leaves_the_roster()
    {
        var (student, classroom) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");
        await EnrollAsync(teacher, classroom, student);

        var response = await UnenrollAsync(teacher, classroom, student);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Empty(await RosterAsync(teacher, classroom));
    }

    [Fact]
    public async Task Dropped_student_can_be_enrolled_again()
    {
        var (student, classroom) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");
        await EnrollAsync(teacher, classroom, student);
        await UnenrollAsync(teacher, classroom, student);

        var again = await EnrollAsync(teacher, classroom, student);

        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        var entry = Assert.Single(await RosterAsync(teacher, classroom));
        Assert.Equal("Active", entry.GetProperty("status").GetString());
        Assert.Equal(JsonValueKind.Null, entry.GetProperty("unenrolledAt").ValueKind);
    }

    [Fact]
    public async Task Enrolling_an_active_student_twice_is_a_conflict()
    {
        var (student, classroom) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");
        await EnrollAsync(teacher, classroom, student);

        var second = await EnrollAsync(teacher, classroom, student);

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Unenrolling_a_student_who_already_left_is_not_found()
    {
        var (student, classroom) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");
        await EnrollAsync(teacher, classroom, student);
        await UnenrollAsync(teacher, classroom, student);

        var second = await UnenrollAsync(teacher, classroom, student);

        Assert.Equal(HttpStatusCode.NotFound, second.StatusCode);
    }
}
