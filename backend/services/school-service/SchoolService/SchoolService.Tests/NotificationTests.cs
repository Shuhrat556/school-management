using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F3: students and their parents hear about new grades, absences and class announcements.
public class NotificationTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Student Student, Guid StudentAuthId, Guid ParentId, Subject Subject, Classroom Classroom, Teacher Teacher, Guid TeacherAuthId);

    private async Task<World> SeedAsync()
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Nodira", "Aliyeva", studentAuthId);
        var teacherAuthId = Guid.NewGuid();
        var teacher = new Teacher("Anvar", "Qodirov", teacherAuthId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Subject subject = null!;
        Classroom classroom = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Teachers.Add(teacher);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            subject = new Subject($"Chemistry {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            classroom = new Classroom($"CH-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
        });

        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{student.Id}/parents",
            new { parentAuthUserId = parentId, fullName = "Parent Aliyeva" });
        return new World(student, studentAuthId, parentId, subject, classroom, teacher, teacherAuthId);
    }

    private static async Task<JsonElement[]> FeedAsync(HttpClient client)
        => (await client.GetFromJsonAsync<JsonElement>("/api/school/notifications")).EnumerateArray().ToArray();

    private static async Task<int> UnreadAsync(HttpClient client)
        => (await client.GetFromJsonAsync<JsonElement>("/api/school/notifications/unread-count")).GetProperty("count").GetInt32();

    [Fact]
    public async Task New_grade_reaches_student_and_parent()
    {
        var w = await SeedAsync();
        var student = factory.CreateClientAs("Student", w.StudentAuthId);
        var parent = factory.CreateClientAs("Parent", w.ParentId);

        await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/grades",
            new { studentId = w.Student.Id, subjectId = w.Subject.Id, score = 91, semester = "1" });

        var studentFeed = await FeedAsync(student);
        var parentFeed = await FeedAsync(parent);
        Assert.StartsWith("New grade in Chemistry", Assert.Single(studentFeed).GetProperty("title").GetString());
        Assert.Equal("Nodira Aliyeva", Assert.Single(parentFeed).GetProperty("studentName").GetString());
        Assert.Equal(1, await UnreadAsync(student));
    }

    [Fact]
    public async Task Reading_notifications_clears_the_unread_count()
    {
        var w = await SeedAsync();
        var parent = factory.CreateClientAs("Parent", w.ParentId);
        var teacher = factory.CreateClientAs("Teacher");
        await teacher.PostAsJsonAsync("/api/school/grades", new { studentId = w.Student.Id, subjectId = w.Subject.Id, score = 60, semester = "1" });
        await teacher.PostAsJsonAsync("/api/school/grades", new { studentId = w.Student.Id, subjectId = w.Subject.Id, score = 75, semester = "1" });
        var feed = await FeedAsync(parent);
        Assert.Equal(2, await UnreadAsync(parent));

        var readOne = await parent.PostAsync($"/api/school/notifications/{feed[0].GetProperty("id").GetGuid()}/read", null);
        Assert.Equal(HttpStatusCode.NoContent, readOne.StatusCode);
        Assert.Equal(1, await UnreadAsync(parent));

        await parent.PostAsync("/api/school/notifications/read-all", null);
        Assert.Equal(0, await UnreadAsync(parent));
    }

    [Fact]
    public async Task Absence_is_reported_once_and_presence_not_at_all()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");
        object Mark(int status) => new { classroomId = w.Classroom.Id, date = "2026-09-21", records = new[] { new { studentId = w.Student.Id, status } } };

        await teacher.PostAsJsonAsync("/api/school/attendance/mark", Mark(1));
        await teacher.PostAsJsonAsync("/api/school/attendance/mark", Mark(2));
        await teacher.PostAsJsonAsync("/api/school/attendance/mark", Mark(2));

        var feed = await FeedAsync(factory.CreateClientAs("Student", w.StudentAuthId));
        Assert.Equal("Marked absent", Assert.Single(feed).GetProperty("title").GetString());
    }

    [Fact]
    public async Task Published_class_announcement_reaches_enrolled_families()
    {
        var w = await SeedAsync();

        var created = await factory.CreateClientAs("Teacher", w.TeacherAuthId).PostAsJsonAsync("/api/announcements", new
        {
            title = "Field trip",
            body = "Bring a signed permission slip on Friday.",
            authorTeacherId = w.Teacher.Id,
            classroomId = w.Classroom.Id,
            publishImmediately = true
        });

        Assert.True(created.IsSuccessStatusCode, await created.Content.ReadAsStringAsync());
        var parentFeed = await FeedAsync(factory.CreateClientAs("Parent", w.ParentId));
        Assert.Equal("New announcement: Field trip", Assert.Single(parentFeed).GetProperty("title").GetString());
    }

    [Fact]
    public async Task Nobody_can_read_someone_elses_notification()
    {
        var w = await SeedAsync();
        await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/grades",
            new { studentId = w.Student.Id, subjectId = w.Subject.Id, score = 88, semester = "1" });
        var id = (await FeedAsync(factory.CreateClientAs("Parent", w.ParentId)))[0].GetProperty("id").GetGuid();

        var otherParent = await factory.CreateClientAs("Parent").PostAsync($"/api/school/notifications/{id}/read", null);
        var teacher = await factory.CreateClientAs("Teacher").GetAsync("/api/school/notifications");

        Assert.Equal(HttpStatusCode.NotFound, otherParent.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, teacher.StatusCode);
    }
}
