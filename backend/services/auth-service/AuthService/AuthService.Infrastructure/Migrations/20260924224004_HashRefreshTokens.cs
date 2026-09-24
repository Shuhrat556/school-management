using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AuthService.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class HashRefreshTokens : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Tokens are now stored as base64(SHA-256(token)), matching TokenService.HashRefreshToken.
            // Hash the rows issued before this release so existing sessions keep working.
            migrationBuilder.Sql(
                "UPDATE \"RefreshTokens\" SET \"Token\" = encode(sha256(convert_to(\"Token\", 'UTF8')), 'base64');");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_Token",
                table: "RefreshTokens",
                column: "Token");
        }

        /// <inheritdoc />
        // Hashes can't be reversed: after rolling back, stored tokens no longer match
        // anything the old code compares against, so users simply sign in again.
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RefreshTokens_Token",
                table: "RefreshTokens");
        }
    }
}
