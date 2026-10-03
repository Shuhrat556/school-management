using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B25: attendance could be recorded for students who are not in the class (or do not exist).
public class AttendanceTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private async Task<(Student Enrolled, Student Outsider, Classroom Classroom)> SeedAsync()
    {
        var enrolled = new Student("In", "Class");
        var outsider = new Student("Not", "Enrolled");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Classroom classroom = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.AddRange(enrolled, outsider);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Art {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            classroom = new Classroom($"AR-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(enrolled.Id, classroom.Id));
            await db.SaveChangesAsync();
        });
        return (enrolled, outsider, classroom);
    }

    private Task<HttpResponseMessage> MarkAsync(Classroom classroom, params (Guid StudentId, int Status)[] records)
        => factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/attendance/mark", new
        {
            classroomId = classroom.Id,
            date = "2026-09-28",
            records = records.Select(r => new { studentId = r.StudentId, status = r.Status })
        });

    private Task<int> MarksAsync(Classroom classroom)
        => factory.WithDbAsync(db => db.Attendances.CountAsync(a => a.ClassroomId == classroom.Id));

    [Fact]
    public async Task Enrolled_students_are_marked_and_listed_for_the_day()
    {
        var (enrolled, _, classroom) = await SeedAsync();

        var response = await MarkAsync(classroom, (enrolled.Id, 3));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var sheet = (await factory.CreateClientAs("Teacher")
            .GetFromJsonAsync<JsonElement>($"/api/school/attendance?classroomId={classroom.Id}&date=2026-09-28")).EnumerateArray().ToArray();
        Assert.Equal("Late", Assert.Single(sheet).GetProperty("status").GetString());
        Assert.Equal("In Class", sheet[0].GetProperty("studentName").GetString());
    }

    [Fact]
    public async Task A_student_who_is_not_in_the_class_rejects_the_whole_batch()
    {
        var (enrolled, outsider, classroom) = await SeedAsync();

        var response = await MarkAsync(classroom, (enrolled.Id, 1), (outsider.Id, 2));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("Not Enrolled", await response.Content.ReadAsStringAsync());
        Assert.Equal(0, await MarksAsync(classroom));
    }

    [Fact]
    public async Task An_unknown_student_is_a_bad_request()
    {
        var (_, _, classroom) = await SeedAsync();

        var response = await MarkAsync(classroom, (Guid.NewGuid(), 1));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task An_existing_mark_can_be_corrected_after_the_student_left()
    {
        var (enrolled, _, classroom) = await SeedAsync();
        await MarkAsync(classroom, (enrolled.Id, 1));
        await factory.CreateClientAs("Teacher").DeleteAsync($"/api/school/classrooms/{classroom.Id}/unenroll/{enrolled.Id}");

        var response = await MarkAsync(classroom, (enrolled.Id, 2));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var mark = await factory.WithDbAsync(db => db.Attendances.AsNoTracking().SingleAsync(a => a.ClassroomId == classroom.Id));
        Assert.Equal(AttendanceStatus.Absent, mark.Status);
    }
}
