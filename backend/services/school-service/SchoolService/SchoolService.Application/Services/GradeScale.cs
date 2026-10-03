namespace SchoolService.Application.Services;

// Letter grades and 4.0 grade points, matching the web portal (admin-web/src/lib/student-portal.js).
public static class GradeScale
{
    public static string Letter(decimal score) => score switch
    {
        >= 90 => "A",
        >= 80 => "B",
        >= 70 => "C",
        >= 60 => "D",
        _     => "F"
    };

    public static decimal Points(decimal score) => score switch
    {
        >= 93 => 4.0m,
        >= 90 => 3.7m,
        >= 87 => 3.3m,
        >= 83 => 3.0m,
        >= 80 => 2.7m,
        >= 77 => 2.3m,
        >= 73 => 2.0m,
        >= 70 => 1.7m,
        >= 67 => 1.3m,
        >= 63 => 1.0m,
        >= 60 => 0.7m,
        _     => 0.0m
    };
}
