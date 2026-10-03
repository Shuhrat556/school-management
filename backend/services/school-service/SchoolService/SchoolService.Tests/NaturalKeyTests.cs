using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// BUGS B16: nothing stopped a second grade for the same student, subject and
// semester, or a second attendance mark for the same student and day.
public class NaturalKeyTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private async Task<(Student Student, Subject Subject, Classroom Classroom)> SeedAsync()
    {
        var student = new Student("Grade", "Student");
        var department = new Department($"Dept {Guid.NewGuid():N}");
        Subject subject = null!;
        Classroom classroom = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            subject = new Subject($"Physics {Guid.NewGuid():N}", department.Id);
            db.Subjects.Add(subject);
            await db.SaveChangesAsync();
            classroom = new Classroom($"PH-{Guid.NewGuid():N}", subject.Id);
            db.Classrooms.Add(classroom);
            await db.SaveChangesAsync();
        });
        return (student, subject, classroom);
    }

    [Fact]
    public async Task Posting_a_grade_again_updates_the_existing_one()
    {
        var (student, subject, _) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");

        var first = await teacher.PostAsJsonAsync("/api/school/grades",
            new { studentId = student.Id, subjectId = subject.Id, score = 70, semester = "1" });
        var second = await teacher.PostAsJsonAsync("/api/school/grades",
            new { studentId = student.Id, subjectId = subject.Id, score = 85, semester = "1" });

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        var grades = await factory.WithDbAsync(db => db.StudentGrades.AsNoTracking()
            .Where(g => g.StudentId == student.Id).ToListAsync());
        Assert.Equal(85m, Assert.Single(grades).Score);
    }

    [Fact]
    public async Task Another_semester_is_a_separate_grade()
    {
        var (student, subject, _) = await SeedAsync();
        var teacher = factory.CreateClientAs("Teacher");

        await teacher.PostAsJsonAsync("/api/school/grades", new { studentId = student.Id, subjectId = subject.Id, score = 70, semester = "1" });
        await teacher.PostAsJsonAsync("/api/school/grades", new { studentId = student.Id, subjectId = subject.Id, score = 90, semester = "2" });

        Assert.Equal(2, await factory.WithDbAsync(db => db.StudentGrades.CountAsync(g => g.StudentId == student.Id)));
    }

    [Fact]
    public async Task Duplicate_rows_in_one_attendance_request_keep_the_last_status()
    {
        var (student, _, classroom) = await SeedAsync();
        await factory.WithDbAsync(async db =>
        {
            db.StudentClassrooms.Add(new StudentClassroom(student.Id, classroom.Id));
            await db.SaveChangesAsync();
        });

        var response = await factory.CreateClientAs("Teacher").PostAsJsonAsync("/api/school/attendance/mark", new
        {
            classroomId = classroom.Id,
            date = "2026-09-25",
            records = new[] { new { studentId = student.Id, status = 1 }, new { studentId = student.Id, status = 3 } }
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var marks = await factory.WithDbAsync(db => db.Attendances.AsNoTracking()
            .Where(a => a.StudentId == student.Id).ToListAsync());
        Assert.Equal(AttendanceStatus.Late, Assert.Single(marks).Status);
    }
}
