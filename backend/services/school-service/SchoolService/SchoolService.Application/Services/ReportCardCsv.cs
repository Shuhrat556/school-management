using System.Globalization;
using System.Text;
using SchoolService.Application.DTOs.ReportCards;

namespace SchoolService.Application.Services;

// RFC 4180 CSV of a report card: a short header block, one row per subject, then the totals.
public static class ReportCardCsv
{
    public static string Write(ReportCardDto card)
    {
        var csv = new StringBuilder();
        Row(csv, "Student", card.StudentName);
        Row(csv, "Semester", card.Semester ?? "All");
        if (card.From != null || card.To != null)
            Row(csv, "Attendance period", $"{card.From?.ToString("yyyy-MM-dd") ?? "…"} – {card.To?.ToString("yyyy-MM-dd") ?? "…"}");
        Row(csv, "Generated (UTC)", card.GeneratedAt.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture));
        csv.Append("\r\n");

        Row(csv, "Subject", "Semester", "Score", "Letter", "Grade points");
        foreach (var s in card.Subjects)
            Row(csv, s.SubjectName, s.Semester, Number(s.Score, "0.##"), s.Letter, Number(s.GradePoints, "0.0"));
        csv.Append("\r\n");

        Row(csv, "Average score", Number(card.AverageScore, "0.##"));
        Row(csv, "GPA", Number(card.Gpa, "0.##"));
        Row(csv, "Attendance (present / total)", $"{card.Attendance.Present} / {card.Attendance.Total}");
        Row(csv, "Absent", card.Attendance.Absent.ToString(CultureInfo.InvariantCulture));
        Row(csv, "Late", card.Attendance.Late.ToString(CultureInfo.InvariantCulture));
        Row(csv, "Attendance rate (%)", Number(card.Attendance.Rate, "0.#"));
        return csv.ToString();
    }

    private static string Number(decimal? value, string format)
        => value?.ToString(format, CultureInfo.InvariantCulture) ?? "";

    private static void Row(StringBuilder csv, params string[] cells)
    {
        csv.AppendJoin(',', cells.Select(Cell));
        csv.Append("\r\n");
    }

    private static string Cell(string value)
    {
        // A leading = + - @ (or tab/CR) would run as a formula in Excel or Sheets (OWASP "CSV injection").
        if (value.Length > 0 && "=+-@\t\r".Contains(value[0]))
            value = "'" + value;
        return value.IndexOfAny([',', '"', '\r', '\n']) >= 0
            ? "\"" + value.Replace("\"", "\"\"") + "\""
            : value;
    }
}
