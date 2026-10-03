using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SchoolService.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddGradeChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GradeChanges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    GradeId = table.Column<Guid>(type: "uuid", nullable: false),
                    StudentId = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectId = table.Column<Guid>(type: "uuid", nullable: false),
                    Semester = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Action = table.Column<int>(type: "integer", nullable: false),
                    OldScore = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: true),
                    NewScore = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: true),
                    ChangedByAuthUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ChangedByName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    ChangedByRole = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    ChangedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GradeChanges", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GradeChanges_GradeId",
                table: "GradeChanges",
                column: "GradeId");

            migrationBuilder.CreateIndex(
                name: "IX_GradeChanges_StudentId_ChangedAt",
                table: "GradeChanges",
                columns: new[] { "StudentId", "ChangedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GradeChanges");
        }
    }
}
