namespace SchoolService.API.Authorization;

// Role names as issued by auth-service in the JWT role claim.
public static class Roles
{
    public const string Admin = "Admin";
    public const string Teacher = "Teacher";
    public const string Student = "Student";
    public const string Parent = "Parent";

    // For [Authorize(Roles = ...)]: comma means "any of".
    public const string Staff = Admin + "," + Teacher;
}
