using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B24: only teacher clashes were checked; a class or a room could be booked twice at the same time.
public class ScheduleConflictTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Subject Subject, Classroom ClassA, Classroom ClassB, Teacher TeacherA, Teacher TeacherB);

    // Two classrooms of one subject; both meet in the same room unless roomType is null.
    private async Task<World> SeedAsync(RoomType? roomType = RoomType.Classroom)
    {
        var department = new Department($"Dept {Guid.NewGuid():N}");
        var teacherA = new Teacher("Ali", "Karimov");
        var teacherB = new Teacher("Vali", "Saidov");
        Subject subject = null!;
        Classroom classA = null!, classB = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Departments.Add(department);
            db.Teachers.AddRange(teacherA, teacherB);
            Room? room = roomType == null ? null : new Room($"R-{Guid.NewGuid():N}", type: roomType.Value);
            if (room != null) db.Rooms.Add(room);
            await db.SaveChangesAsync();
            subject = new Subject($"Music {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            classA = new Classroom($"MU-A-{Guid.NewGuid():N}", subject.Id);
            classB = new Classroom($"MU-B-{Guid.NewGuid():N}", subject.Id);
            classA.UpdateInfo(classA.Name, null, null, null, room?.Id);
            classB.UpdateInfo(classB.Name, null, null, null, room?.Id);
            db.Classrooms.AddRange(classA, classB);
            await db.SaveChangesAsync();
        });
        return new World(subject, classA, classB, teacherA, teacherB);
    }

    private static object Session(World w, Classroom classroom, Teacher? teacher, string start, string end, int day = 1)
        => new { classroomId = classroom.Id, subjectId = w.Subject.Id, teacherId = teacher?.Id, dayOfWeek = day, startTime = start, endTime = end };

    private async Task<HttpResponseMessage> CreateAsync(object session)
        => await factory.CreateClientAs("Admin").PostAsJsonAsync("/api/school/schedules", session);

    private static async Task<string?> CodeAsync(HttpResponseMessage response)
        => (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString();

    [Fact]
    public async Task Teacher_cannot_teach_two_classes_at_once()
    {
        var w = await SeedAsync(roomType: null);
        Assert.Equal(HttpStatusCode.Created, (await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"))).StatusCode);

        var clash = await CreateAsync(Session(w, w.ClassB, w.TeacherA, "09:30", "10:30"));

        Assert.Equal(HttpStatusCode.Conflict, clash.StatusCode);
        Assert.Equal("SCHEDULE_CONFLICT", await CodeAsync(clash));
    }

    [Fact]
    public async Task Class_cannot_have_two_sessions_at_once()
    {
        var w = await SeedAsync(roomType: null);
        await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"));

        var clash = await CreateAsync(Session(w, w.ClassA, w.TeacherB, "09:45", "11:00"));

        Assert.Equal(HttpStatusCode.Conflict, clash.StatusCode);
    }

    [Fact]
    public async Task Room_cannot_host_two_classes_at_once()
    {
        var w = await SeedAsync(RoomType.Lab);
        await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"));

        var clash = await CreateAsync(Session(w, w.ClassB, w.TeacherB, "09:00", "10:00"));

        Assert.Equal(HttpStatusCode.Conflict, clash.StatusCode);
    }

    [Fact]
    public async Task Gym_can_host_two_classes_at_once()
    {
        var w = await SeedAsync(RoomType.Gym);
        await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"));

        var shared = await CreateAsync(Session(w, w.ClassB, w.TeacherB, "09:00", "10:00"));

        Assert.Equal(HttpStatusCode.Created, shared.StatusCode);
    }

    [Fact]
    public async Task Back_to_back_and_other_day_sessions_are_fine()
    {
        var w = await SeedAsync();
        await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"));

        Assert.Equal(HttpStatusCode.Created, (await CreateAsync(Session(w, w.ClassA, w.TeacherA, "10:00", "11:00"))).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await CreateAsync(Session(w, w.ClassB, w.TeacherA, "09:00", "10:00", day: 2))).StatusCode);
    }

    [Fact]
    public async Task Moving_a_session_does_not_clash_with_itself_but_does_with_others()
    {
        var w = await SeedAsync();
        var first = await (await CreateAsync(Session(w, w.ClassA, w.TeacherA, "09:00", "10:00"))).Content.ReadFromJsonAsync<JsonElement>();
        await CreateAsync(Session(w, w.ClassB, w.TeacherB, "11:00", "12:00"));
        var admin = factory.CreateClientAs("Admin");
        var url = $"/api/school/schedules/{first.GetProperty("id").GetGuid()}";

        var later = await admin.PutAsJsonAsync(url, new { teacherId = w.TeacherA.Id, dayOfWeek = 1, startTime = "09:30", endTime = "10:30" });
        var intoTheRoom = await admin.PutAsJsonAsync(url, new { teacherId = w.TeacherA.Id, dayOfWeek = 1, startTime = "11:30", endTime = "12:30" });

        Assert.Equal(HttpStatusCode.OK, later.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, intoTheRoom.StatusCode);
    }

    [Fact]
    public async Task End_before_start_is_rejected()
    {
        var w = await SeedAsync();

        var response = await CreateAsync(Session(w, w.ClassA, w.TeacherA, "10:00", "09:00"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Unknown_teacher_is_not_found()
    {
        var w = await SeedAsync();

        var response = await CreateAsync(Session(w, w.ClassA, new Teacher("Ghost", "Teacher"), "09:00", "10:00"));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
