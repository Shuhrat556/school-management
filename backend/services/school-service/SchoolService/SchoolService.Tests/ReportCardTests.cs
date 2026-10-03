using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using SchoolService.Domain.Entities;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// F4: a student's report card (scores, letters, GPA, attendance) computed on the server, as JSON or CSV.
public class ReportCardTests(SchoolApiFactory factory) : IClassFixture<SchoolApiFactory>
{
    private sealed record World(Student Student, Guid StudentAuthId, Subject Algebra, Subject Biology);

    private async Task<World> SeedAsync(string? biologyName = null)
    {
        var studentAuthId = Guid.NewGuid();
        var student = new Student("Report", "Card", studentAuthId);
        var department = new Department($"Dept {Guid.NewGuid():N}");
        var suffix = Guid.NewGuid().ToString("N");
        Subject algebra = null!, biology = null!;
        await factory.WithDbAsync(async db =>
        {
            db.Students.Add(student);
            db.Departments.Add(department);
            await db.SaveChangesAsync();
            algebra = new Subject($"Algebra {suffix}", department.Id);
            biology = new Subject(biologyName ?? $"Biology {suffix}", department.Id);
            db.Subjects.AddRange(algebra, biology);
            db.StudentGrades.AddRange(
                new StudentGrade(student.Id, algebra.Id, 95, "S1"),
                new StudentGrade(student.Id, biology.Id, 72, "S1"),
                new StudentGrade(student.Id, algebra.Id, 80, "S2"));
            db.Attendances.AddRange(
                new Attendance(student.Id, null, new DateOnly(2026, 9, 1), AttendanceStatus.Present),
                new Attendance(student.Id, null, new DateOnly(2026, 9, 2), AttendanceStatus.Absent),
                new Attendance(student.Id, null, new DateOnly(2026, 9, 3), AttendanceStatus.Late),
                new Attendance(student.Id, null, new DateOnly(2026, 9, 4), AttendanceStatus.Present));
            await db.SaveChangesAsync();
        });
        return new World(student, studentAuthId, algebra, biology);
    }

    private static async Task<JsonElement> GetCardAsync(HttpClient client, Guid studentId, string query = "")
    {
        var response = await client.GetAsync($"/api/school/students/{studentId}/report-card{query}");
        Assert.True(response.StatusCode == HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    [Fact]
    public async Task Semester_report_card_has_scores_letters_gpa_and_attendance()
    {
        var w = await SeedAsync();

        var card = await GetCardAsync(factory.CreateClientAs("Teacher"), w.Student.Id, "?semester=S1");

        Assert.Equal("Report Card", card.GetProperty("studentName").GetString());
        Assert.Equal("S1", card.GetProperty("semester").GetString());
        var subjects = card.GetProperty("subjects").EnumerateArray().ToArray();
        Assert.Equal([w.Algebra.SubjectName, w.Biology.SubjectName], subjects.Select(s => s.GetProperty("subjectName").GetString()));
        Assert.Equal(["A", "C"], subjects.Select(s => s.GetProperty("letter").GetString()));
        Assert.Equal([4.0m, 1.7m], subjects.Select(s => s.GetProperty("gradePoints").GetDecimal()));
        Assert.Equal(83.5m, card.GetProperty("averageScore").GetDecimal());
        Assert.Equal(2.85m, card.GetProperty("gpa").GetDecimal());

        var attendance = card.GetProperty("attendance");
        Assert.Equal(4, attendance.GetProperty("total").GetInt32());
        Assert.Equal(2, attendance.GetProperty("present").GetInt32());
        Assert.Equal(1, attendance.GetProperty("absent").GetInt32());
        Assert.Equal(1, attendance.GetProperty("late").GetInt32());
        Assert.Equal(50m, attendance.GetProperty("rate").GetDecimal());
    }

    [Fact]
    public async Task Without_a_semester_every_grade_counts()
    {
        var w = await SeedAsync();

        var card = await GetCardAsync(factory.CreateClientAs("Admin"), w.Student.Id);

        Assert.Equal(JsonValueKind.Null, card.GetProperty("semester").ValueKind);
        Assert.Equal(3, card.GetProperty("subjects").GetArrayLength());
        Assert.Equal(82.33m, card.GetProperty("averageScore").GetDecimal());
        Assert.Equal(2.8m, card.GetProperty("gpa").GetDecimal());
    }

    [Fact]
    public async Task Attendance_can_be_limited_to_a_date_range()
    {
        var w = await SeedAsync();

        var card = await GetCardAsync(factory.CreateClientAs("Admin"), w.Student.Id, "?from=2026-09-02&to=2026-09-03");

        var attendance = card.GetProperty("attendance");
        Assert.Equal(2, attendance.GetProperty("total").GetInt32());
        Assert.Equal(0m, attendance.GetProperty("rate").GetDecimal());
    }

    [Fact]
    public async Task Student_with_no_records_gets_an_empty_card()
    {
        var student = new Student("Empty", "Record");
        await factory.WithDbAsync(async db => { db.Students.Add(student); await db.SaveChangesAsync(); });

        var card = await GetCardAsync(factory.CreateClientAs("Admin"), student.Id);

        Assert.Equal(0, card.GetProperty("subjects").GetArrayLength());
        Assert.Equal(JsonValueKind.Null, card.GetProperty("averageScore").ValueKind);
        Assert.Equal(JsonValueKind.Null, card.GetProperty("gpa").ValueKind);
        Assert.Equal(JsonValueKind.Null, card.GetProperty("attendance").GetProperty("rate").ValueKind);
    }

    [Fact]
    public async Task Student_and_linked_parent_see_the_card_others_do_not()
    {
        var w = await SeedAsync();
        var parentId = Guid.NewGuid();
        await factory.CreateClientAs("Admin").PostAsJsonAsync($"/api/school/students/{w.Student.Id}/parents",
            new { parentAuthUserId = parentId, fullName = "Parent Card" });
        var url = $"/api/school/students/{w.Student.Id}/report-card";

        Assert.Equal(HttpStatusCode.OK, (await factory.CreateClientAs("Student", w.StudentAuthId).GetAsync(url)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await factory.CreateClientAs("Parent", parentId).GetAsync(url + "/csv")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await factory.CreateClientAs("Student").GetAsync(url)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await factory.CreateClientAs("Parent").GetAsync(url + "/csv")).StatusCode);
    }

    [Fact]
    public async Task Reversed_date_range_is_rejected()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Admin")
            .GetAsync($"/api/school/students/{w.Student.Id}/report-card?from=2026-09-05&to=2026-09-01");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Unknown_student_is_not_found()
    {
        var response = await factory.CreateClientAs("Admin").GetAsync($"/api/school/students/{Guid.NewGuid()}/report-card");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Csv_export_is_a_download_with_one_row_per_subject()
    {
        var w = await SeedAsync();

        var response = await factory.CreateClientAs("Teacher").GetAsync($"/api/school/students/{w.Student.Id}/report-card/csv?semester=S1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/csv", response.Content.Headers.ContentType?.MediaType);
        Assert.Equal("attachment", response.Content.Headers.ContentDisposition?.DispositionType);
        Assert.Equal("report-card-report-card-s1.csv", response.Content.Headers.ContentDisposition?.FileNameStar);
        var lines = (await response.Content.ReadAsStringAsync()).TrimStart('﻿').Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal("Student,Report Card", lines[0]);
        Assert.Equal("Semester,S1", lines[1]);
        var header = Array.IndexOf(lines, "Subject,Semester,Score,Letter,Grade points");
        Assert.True(header > 0);
        Assert.Equal($"{w.Algebra.SubjectName},S1,95,A,4.0", lines[header + 1]);
        Assert.Equal($"{w.Biology.SubjectName},S1,72,C,1.7", lines[header + 2]);
        Assert.Contains("Average score,83.5", lines);
        Assert.Contains("GPA,2.85", lines);
        Assert.Contains("Attendance rate (%),50", lines);
    }

    [Fact]
    public async Task Csv_cells_cannot_start_a_formula()
    {
        var w = await SeedAsync(biologyName: $"=HYPERLINK(\"x\",\"y\") {Guid.NewGuid():N}");

        var csv = await factory.CreateClientAs("Admin").GetStringAsync($"/api/school/students/{w.Student.Id}/report-card/csv");

        Assert.Contains($"\"'{w.Biology.SubjectName.Replace("\"", "\"\"")}\",S1,72,C,1.7", csv);
    }
}
