using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SchoolService.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNaturalKeyIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The new composite indexes start with StudentId, so the single-column ones go.
            // IF EXISTS: some old EnsureCreated databases may never have had them.
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_StudentGrades_StudentId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Attendances_StudentId\";");

            migrationBuilder.CreateIndex(
                name: "IX_StudentGrades_StudentId_SubjectId_Semester",
                table: "StudentGrades",
                columns: new[] { "StudentId", "SubjectId", "Semester" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Attendances_StudentId_ClassroomId_Date",
                table: "Attendances",
                columns: new[] { "StudentId", "ClassroomId", "Date" },
                unique: true);

            // Emails identify the profile for sign-in lookups: unique ignoring case, only
            // where set. EF can't model expression indexes, so these live here only.
            migrationBuilder.Sql(
                "CREATE UNIQUE INDEX \"IX_Students_Email_Lower\" ON \"Students\" (lower(\"Email\")) WHERE \"Email\" IS NOT NULL;");
            migrationBuilder.Sql(
                "CREATE UNIQUE INDEX \"IX_Teachers_Email_Lower\" ON \"Teachers\" (lower(\"Email\")) WHERE \"Email\" IS NOT NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Students_Email_Lower\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Teachers_Email_Lower\";");

            migrationBuilder.DropIndex(
                name: "IX_StudentGrades_StudentId_SubjectId_Semester",
                table: "StudentGrades");

            migrationBuilder.DropIndex(
                name: "IX_Attendances_StudentId_ClassroomId_Date",
                table: "Attendances");

            migrationBuilder.CreateIndex(
                name: "IX_StudentGrades_StudentId",
                table: "StudentGrades",
                column: "StudentId");

            migrationBuilder.CreateIndex(
                name: "IX_Attendances_StudentId",
                table: "Attendances",
                column: "StudentId");
        }
    }
}
