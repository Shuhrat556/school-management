using System.Net;
using System.Net.Http.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B48: any teacher could grade any student, mark attendance for any class and move
// students between classes they don't teach (D4 planned resource-level rules).
public class TeacherScopeTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Guid TeacherAuthId, Guid MyClass, Guid OtherClass, Guid MyStudent, Guid OtherStudent, Guid SubjectId);

    private async Task<World> SeedAsync()
    {
        var teacherAuthId = Guid.NewGuid();
        var teacher = new Teacher("Scope", "Teacher", teacherAuthId);
        var colleague = new Teacher("Other", "Colleague", Guid.NewGuid());
        var mine = new Student("My", "Student");
        var other = new Student("Their", "Student");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Guid myClass = default, otherClass = default, subjectId = default;
        await factory.WithDbAsync(async db =>
        {
            db.Teachers.AddRange(teacher, colleague);
            db.Students.AddRange(mine, other);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Maths {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            var a = new Classroom($"MA-{Guid.NewGuid():N}", subject.Id);
            a.AssignTeacher(teacher.Id);
            var b = new Classroom($"MB-{Guid.NewGuid():N}", subject.Id);
            b.AssignTeacher(colleague.Id);
            db.Classrooms.AddRange(a, b);
            await db.SaveChangesAsync();
            db.StudentClassrooms.AddRange(new StudentClassroom(mine.Id, a.Id), new StudentClassroom(other.Id, b.Id));
            await db.SaveChangesAsync();
            myClass = a.Id; otherClass = b.Id; subjectId = subject.Id;
        });
        return new World(teacherAuthId, myClass, otherClass, mine.Id, other.Id, subjectId);
    }

    private static object Grade(World w, Guid studentId) => new { studentId, subjectId = w.SubjectId, score = 80, semester = "1" };

    private static object Mark(Guid classroomId, Guid studentId) =>
        new { classroomId, date = "2026-10-05", records = new[] { new { studentId, status = 1 } } };

    [Fact]
    public async Task A_teacher_grades_only_students_they_teach()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);

        Assert.Equal(HttpStatusCode.Created, (await teacher.PostAsJsonAsync("/api/school/grades", Grade(w, w.MyStudent))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await teacher.PostAsJsonAsync("/api/school/grades", Grade(w, w.OtherStudent))).StatusCode);
    }

    [Fact]
    public async Task A_teacher_cannot_change_or_delete_a_grade_of_someone_elses_student()
    {
        var w = await SeedAsync();
        var created = await factory.CreateClientAs("Admin").PostAsJsonAsync("/api/school/grades", Grade(w, w.OtherStudent));
        var gradeId = (await created.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>()).GetProperty("id").GetGuid();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);

        var update = await teacher.PutAsJsonAsync($"/api/school/grades/{gradeId}", new { score = 10, semester = "1" });
        var delete = await teacher.DeleteAsync($"/api/school/grades/{gradeId}");

        Assert.Equal(HttpStatusCode.Forbidden, update.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, delete.StatusCode);
    }

    [Fact]
    public async Task A_teacher_marks_attendance_only_for_their_classes()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);

        Assert.Equal(HttpStatusCode.OK, (await teacher.PostAsJsonAsync("/api/school/attendance/mark", Mark(w.MyClass, w.MyStudent))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await teacher.PostAsJsonAsync("/api/school/attendance/mark", Mark(w.OtherClass, w.OtherStudent))).StatusCode);
    }

    [Fact]
    public async Task A_teacher_cannot_move_students_in_a_class_they_dont_teach()
    {
        var w = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher", w.TeacherAuthId);

        var unenroll = await teacher.DeleteAsync($"/api/school/classrooms/{w.OtherClass}/unenroll/{w.OtherStudent}");
        var enroll = await teacher.PostAsJsonAsync($"/api/school/classrooms/{w.OtherClass}/enroll", new { studentId = w.MyStudent });

        Assert.Equal(HttpStatusCode.Forbidden, unenroll.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, enroll.StatusCode);
    }

    [Fact]
    public async Task A_teacher_account_without_a_school_profile_cannot_grade()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/grades", Grade(w, w.MyStudent));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admins_are_not_limited()
    {
        var w = await SeedAsync();
        var admin = factory.CreateClientAs("Admin");

        Assert.Equal(HttpStatusCode.Created, (await admin.PostAsJsonAsync("/api/school/grades", Grade(w, w.OtherStudent))).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.PostAsJsonAsync("/api/school/attendance/mark", Mark(w.OtherClass, w.OtherStudent))).StatusCode);
    }
}
