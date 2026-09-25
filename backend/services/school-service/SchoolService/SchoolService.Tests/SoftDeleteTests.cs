using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B17: deleting a student removed the row and, by cascade, all of their
// grades, attendance and submissions.
public class SoftDeleteTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    [Fact]
    public async Task Deleting_a_student_hides_them_but_keeps_their_records()
    {
        var authId = Guid.NewGuid();
        var student = new Student("Leaving", "Student", authId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Guid subjectId = default, classroomId = default;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            var subject = new Subject($"Art {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            db.StudentGrades.Add(new StudentGrade(student.Id, subject.Id, 77, "1"));
            var classroom = new Classroom($"ART-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
            subjectId = subject.Id;
            classroomId = classroom.Id;
        });
        var admin = factory.CreateClientAs("Admin");

        var delete = await admin.DeleteAsync($"/api/school/students/{student.Id}");

        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await admin.GetAsync($"/api/school/students/{student.Id}")).StatusCode);
        var list = await admin.GetFromJsonAsync<JsonElement>("/api/school/students");
        Assert.DoesNotContain(list.EnumerateArray(), s => s.GetProperty("id").GetGuid() == student.Id);
        Assert.Equal(HttpStatusCode.NotFound,
            (await factory.CreateClientAs("Student", authId).GetAsync("/api/school/students/me")).StatusCode);
        var newGrade = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/grades",
            new { studentId = student.Id, subjectId, score = 50, semester = "2" });
        Assert.Equal(HttpStatusCode.NotFound, newGrade.StatusCode);

        var roster = await admin.GetFromJsonAsync<JsonElement>($"/api/school/classrooms/{classroomId}");
        Assert.Empty(roster.GetProperty("students").EnumerateArray());

        var (row, grades) = await factory.WithDbAsync(async db => (
            await db.Students.AsNoTracking().SingleAsync(s => s.Id == student.Id),
            await db.StudentGrades.CountAsync(g => g.StudentId == student.Id)));
        Assert.NotNull(row.DeletedAt);
        Assert.False(row.IsActive);
        Assert.Equal(1, grades);
    }

    [Fact]
    public async Task Deleting_a_teacher_hides_them_but_keeps_the_row()
    {
        var teacher = new Teacher("Leaving", "Teacher");
        await factory.WithDbAsync(async db => { db.Teachers.Add(teacher); await db.SaveChangesAsync(); });
        var admin = factory.CreateClientAs("Admin");

        var delete = await admin.DeleteAsync($"/api/school/teachers/{teacher.Id}");

        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await admin.GetAsync($"/api/school/teachers/{teacher.Id}")).StatusCode);
        var row = await factory.WithDbAsync(db => db.Teachers.AsNoTracking().SingleAsync(t => t.Id == teacher.Id));
        Assert.NotNull(row.DeletedAt);
    }
}
