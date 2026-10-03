using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F5: every grade that is set, changed or removed leaves a record of who did it and when.
public class GradeAuditTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    // A student in a class taught by a teacher with this auth id (teachers grade only their students, B48)
    private async Task<(Student Student, Subject Subject, Guid TeacherAuthId)> SeedAsync()
    {
        var student = new Student("Audit", "Student");
        var teacherAuthId = Guid.NewGuid();
        var teacher = new Teacher("Grade", "Keeper", teacherAuthId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Subject subject = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Teachers.Add(teacher);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            subject = new Subject($"History {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var classroom = new Classroom($"HI-{Guid.NewGuid():N}", subject.Id);
            classroom.AssignTeacher(teacher.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
        });
        return (student, subject, teacherAuthId);
    }

    private static async Task<Guid> SaveGradeAsync(HttpClient client, Student student, Subject subject, decimal score)
    {
        var response = await client.PostAsJsonAsync("/api/school/grades",
            new { studentId = student.Id, subjectId = subject.Id, score, semester = "1" });
        Assert.True(response.IsSuccessStatusCode, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
    }

    private static async Task<JsonElement[]> HistoryAsync(HttpClient client, Guid gradeId)
    {
        var response = await client.GetAsync($"/api/school/grades/{gradeId}/history");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).EnumerateArray().ToArray();
    }

    private static decimal? Score(JsonElement change, string name)
        => change.GetProperty(name).ValueKind == JsonValueKind.Null ? null : change.GetProperty(name).GetDecimal();

    [Fact]
    public async Task Every_change_to_a_grade_is_recorded_with_its_author()
    {
        var (student, subject, teacherAuthId) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", teacherAuthId);

        var gradeId = await SaveGradeAsync(teacher, student, subject, 70);
        await SaveGradeAsync(teacher, student, subject, 85);
        await teacher.PutAsJsonAsync($"/api/school/grades/{gradeId}", new { score = 90, semester = "1" });
        await factory.CreateClientAs("Admin").DeleteAsync($"/api/school/grades/{gradeId}");

        // The history outlives the grade itself.
        var history = await HistoryAsync(factory.CreateClientAs("Admin"), gradeId);
        Assert.Equal(["Created", "Updated", "Updated", "Deleted"], history.Select(c => c.GetProperty("action").GetString()));
        Assert.Equal([null, 70m, 85m, 90m], history.Select(c => Score(c, "oldScore")));
        Assert.Equal([70m, 85m, 90m, null], history.Select(c => Score(c, "newScore")));

        var first = history[0];
        Assert.Equal(teacherAuthId, first.GetProperty("changedByAuthUserId").GetGuid());
        Assert.Equal("Teacher", first.GetProperty("changedByRole").GetString());
        Assert.Equal("Test User", first.GetProperty("changedByName").GetString());
        Assert.Equal("Audit Student", first.GetProperty("studentName").GetString());
        Assert.Equal(subject.SubjectName, first.GetProperty("subjectName").GetString());
        Assert.Equal("Admin", history[3].GetProperty("changedByRole").GetString());
    }

    [Fact]
    public async Task Saving_the_same_score_again_is_not_a_change()
    {
        var (student, subject, teacherAuthId) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", teacherAuthId);

        var gradeId = await SaveGradeAsync(teacher, student, subject, 77);
        await SaveGradeAsync(teacher, student, subject, 77);
        await teacher.PutAsJsonAsync($"/api/school/grades/{gradeId}", new { score = 77, semester = "1" });

        Assert.Single(await HistoryAsync(teacher, gradeId));
    }

    [Fact]
    public async Task Admin_sees_the_recent_changes_for_a_student()
    {
        var (student, subject, teacherAuthId) = await SeedAsync();
        var (other, otherSubject, otherTeacherAuthId) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", teacherAuthId);
        await SaveGradeAsync(teacher, student, subject, 60);
        await SaveGradeAsync(teacher, student, subject, 65);
        await SaveGradeAsync(factory.CreateClientAs("Teacher", otherTeacherAuthId), other, otherSubject, 99);

        var feed = (await factory.CreateClientAs("Admin")
            .GetFromJsonAsync<JsonElement>($"/api/school/grades/changes?studentId={student.Id}")).EnumerateArray().ToArray();

        Assert.Equal(2, feed.Length);
        Assert.All(feed, c => Assert.Equal(student.Id, c.GetProperty("studentId").GetGuid()));
        Assert.Equal(65m, Score(feed[0], "newScore")); // newest first
    }

    [Theory]
    [InlineData("Student")]
    [InlineData("Parent")]
    public async Task Students_and_parents_cannot_read_the_audit_trail(string role)
    {
        var (student, subject, teacherAuthId) = await SeedAsync();
        var gradeId = await SaveGradeAsync(factory.CreateClientAs("Teacher", teacherAuthId), student, subject, 50);
        var client = factory.CreateClientAs(role);

        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync($"/api/school/grades/{gradeId}/history")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/school/grades/changes")).StatusCode);
    }

    [Fact]
    public async Task Only_admin_reads_the_school_wide_feed()
    {
        var response = await factory.CreateClientAs("Teacher").GetAsync("/api/school/grades/changes");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task History_of_an_unknown_grade_is_not_found()
    {
        var response = await factory.CreateClientAs("Admin").GetAsync($"/api/school/grades/{Guid.NewGuid()}/history");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
