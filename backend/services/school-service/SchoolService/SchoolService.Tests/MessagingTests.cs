using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F9: one-to-one messages between a teacher and a student or a parent, only along real
// class relationships (D18).
public class MessagingTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid TeacherId, Guid TeacherAuthId, Guid StudentId, Guid StudentAuthId, Guid ParentId,
        Guid OtherTeacherId, Guid OtherTeacherAuthId, Guid OutsiderStudentId);

    private async Task<World> SeedAsync()
    {
        var teacherAuthId = Guid.NewGuid();
        var otherTeacherAuthId = Guid.NewGuid();
        var studentAuthId = Guid.NewGuid();
        var teacher = new Teacher("Anvar", "Qodirov", teacherAuthId);
        var otherTeacher = new Teacher("Other", "Teacher", otherTeacherAuthId);
        var student = new Student("Nodira", "Aliyeva", studentAuthId);
        var outsider = new Student("Out", "Sider", Guid.NewGuid());
        var department = new Department($"Dept {Guid.NewGuid():N}");
        await factory.WithDbAsync(async db =>
        {
            db.Teachers.AddRange(teacher, otherTeacher);
            db.Students.AddRange(student, outsider);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Physics {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var classroom = new Classroom($"PH-{Guid.NewGuid():N}", subject.Id);
            classroom.AssignTeacher(teacher.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
        });
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{student.Id}/parents",
            new { parentAuthUserId = parentId, fullName = "Malika Aliyeva", relationship = "Mother" });
        return new World(teacher.Id, teacherAuthId, student.Id, studentAuthId, parentId, otherTeacher.Id, otherTeacherAuthId, outsider.Id);
    }

    private static async Task<Guid> StartAsync(HttpClient client, object body)
    {
        var response = await client.PostAsJsonAsync("/api/school/messages/conversations", body);
        Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode} {await response.Content.ReadAsStringAsync()}");
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
    }

    private static Task<HttpResponseMessage> SendAsync(HttpClient client, Guid conversationId, string body)
        => client.PostAsJsonAsync($"/api/school/messages/conversations/{conversationId}/messages", new { body });

    private static async Task<JsonElement[]> MessagesAsync(HttpClient client, Guid conversationId)
        => (await client.GetFromJsonAsync<JsonElement>($"/api/school/messages/conversations/{conversationId}/messages")).EnumerateArray().ToArray();

    private static async Task<JsonElement[]> ConversationsAsync(HttpClient client)
        => (await client.GetFromJsonAsync<JsonElement>("/api/school/messages/conversations")).EnumerateArray().ToArray();

    [Fact]
    public async Task A_teacher_and_a_student_exchange_messages()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);
        var student = factory.CreateClientAs("Student", w.StudentAuthId);

        var id = await StartAsync(teacher, new { studentId = w.StudentId });
        Assert.Equal(HttpStatusCode.Created, (await SendAsync(teacher, id, "Please bring your lab notebook.")).StatusCode);

        var inbox = Assert.Single(await ConversationsAsync(student));
        Assert.Equal("Anvar Qodirov", inbox.GetProperty("title").GetString());
        Assert.Equal(1, inbox.GetProperty("unreadCount").GetInt32());

        var received = Assert.Single(await MessagesAsync(student, id));
        Assert.False(received.GetProperty("isMine").GetBoolean());
        await student.PostAsync($"/api/school/messages/conversations/{id}/read", null);
        await SendAsync(student, id, "Okay, thank you!");

        Assert.Equal(0, Assert.Single(await ConversationsAsync(student)).GetProperty("unreadCount").GetInt32());
        var thread = await MessagesAsync(teacher, id);
        Assert.Equal(["Please bring your lab notebook.", "Okay, thank you!"], thread.Select(m => m.GetProperty("body").GetString()));
        Assert.Equal("Nodira Aliyeva", Assert.Single(await ConversationsAsync(teacher)).GetProperty("title").GetString());
    }

    [Fact]
    public async Task A_parent_writes_to_the_child_teacher()
    {
        var w = await SeedAsync();
        var parent = factory.CreateClientAs("Parent", w.ParentId);

        var id = await StartAsync(parent, new { teacherId = w.TeacherId, studentId = w.StudentId });
        await SendAsync(parent, id, "Nodira will be late tomorrow.");

        var teacherInbox = Assert.Single(await ConversationsAsync(factory.CreateClientAs("Teacher", w.TeacherAuthId)));
        Assert.Equal("Malika Aliyeva", teacherInbox.GetProperty("title").GetString());
        Assert.Equal(1, teacherInbox.GetProperty("unreadCount").GetInt32());
        // The student does not see their parent's conversation
        Assert.Empty(await ConversationsAsync(factory.CreateClientAs("Student", w.StudentAuthId)));
    }

    [Fact]
    public async Task Only_real_class_relationships_can_talk()
    {
        var w = await SeedAsync();

        var parentToStranger = await factory.CreateClientAs("Parent", w.ParentId).PostAsJsonAsync("/api/school/messages/conversations",
            new { teacherId = w.OtherTeacherId, studentId = w.StudentId });
        var studentToStranger = await factory.CreateClientAs("Student", w.StudentAuthId).PostAsJsonAsync("/api/school/messages/conversations",
            new { teacherId = w.OtherTeacherId });
        var teacherToOutsider = await factory.CreateClientAs("Teacher", w.TeacherAuthId).PostAsJsonAsync("/api/school/messages/conversations",
            new { studentId = w.OutsiderStudentId });

        Assert.Equal(HttpStatusCode.Forbidden, parentToStranger.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, studentToStranger.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, teacherToOutsider.StatusCode);
    }

    [Fact]
    public async Task Others_cannot_read_a_conversation()
    {
        var w = await SeedAsync();
        var id = await StartAsync(factory.CreateClientAs("Teacher", w.TeacherAuthId), new { studentId = w.StudentId });

        var otherTeacher = await factory.CreateClientAs("Teacher", w.OtherTeacherAuthId).GetAsync($"/api/school/messages/conversations/{id}/messages");
        var parent = await factory.CreateClientAs("Parent", w.ParentId).GetAsync($"/api/school/messages/conversations/{id}/messages");

        Assert.Equal(HttpStatusCode.NotFound, otherTeacher.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, parent.StatusCode);
    }

    [Fact]
    public async Task Starting_twice_reuses_the_conversation()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);

        var first = await StartAsync(teacher, new { studentId = w.StudentId });
        var second = await StartAsync(factory.CreateClientAs("Student", w.StudentAuthId), new { teacherId = w.TeacherId });

        Assert.Equal(first, second);
    }

    [Fact]
    public async Task Contacts_follow_the_classes()
    {
        var w = await SeedAsync();

        var studentContacts = (await factory.CreateClientAs("Student", w.StudentAuthId).GetFromJsonAsync<JsonElement>("/api/school/messages/contacts")).EnumerateArray().ToArray();
        var teacherContacts = (await factory.CreateClientAs("Teacher", w.TeacherAuthId).GetFromJsonAsync<JsonElement>("/api/school/messages/contacts")).EnumerateArray().ToArray();

        Assert.Equal("Anvar Qodirov", Assert.Single(studentContacts).GetProperty("name").GetString());
        Assert.Equal(["Malika Aliyeva", "Nodira Aliyeva"], teacherContacts.Select(c => c.GetProperty("name").GetString()).OrderBy(n => n));
    }

    [Fact]
    public async Task The_family_is_notified_of_a_teacher_message()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);
        var id = await StartAsync(teacher, new { studentId = w.StudentId });

        await SendAsync(teacher, id, "Great work on the test!");

        var feed = (await factory.CreateClientAs("Student", w.StudentAuthId).GetFromJsonAsync<JsonElement>("/api/school/notifications")).EnumerateArray();
        Assert.Contains(feed, n => n.GetProperty("title").GetString() == "New message from Anvar Qodirov");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(2001)]
    public async Task Empty_or_oversized_messages_are_rejected(int length)
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);
        var id = await StartAsync(teacher, new { studentId = w.StudentId });

        var response = await SendAsync(teacher, id, new string('x', length));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Flooding_a_conversation_is_slowed_down()
    {
        var w = await SeedAsync();
        var student = factory.CreateClientAs("Student", w.StudentAuthId);
        var id = await StartAsync(student, new { teacherId = w.TeacherId });

        for (var i = 0; i < 20; i++)
            await SendAsync(student, id, $"message {i}");
        var tooMany = await SendAsync(student, id, "one more");

        Assert.Equal(HttpStatusCode.TooManyRequests, tooMany.StatusCode);
    }

    [Fact]
    public async Task Admins_have_no_inbox_here()
    {
        var response = await factory.CreateClientAs("Admin").GetAsync("/api/school/messages/conversations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
