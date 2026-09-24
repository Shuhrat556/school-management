using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Attendance;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class AttendanceController : ControllerBase
{
    private readonly IAttendanceService _attendanceService;
    private readonly ProfileAccess _access;

    public AttendanceController(IAttendanceService attendanceService, ProfileAccess access)
    {
        _attendanceService = attendanceService;
        _access = access;
    }

    /// <summary>GET /api/school/attendance?classroomId=&amp;date=YYYY-MM-DD</summary>
    [HttpGet]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult> GetByClassroomAndDate(
        [FromQuery] Guid classroomId,
        [FromQuery] DateOnly date)
    {
        var records = await _attendanceService.GetByClassroomAndDateAsync(classroomId, date);
        return Ok(records);
    }

    /// <summary>GET /api/school/attendance/{studentId}/history</summary>
    [HttpGet("{studentId:guid}/history")]
    public async Task<ActionResult> GetStudentHistory(Guid studentId)
    {
        if (!await _access.CanAccessStudentAsync(User, studentId))
            return Forbid();

        var records = await _attendanceService.GetStudentHistoryAsync(studentId);
        return Ok(records);
    }

    /// <summary>POST /api/school/attendance/mark — bulk mark a whole classroom for a date</summary>
    [HttpPost("mark")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> BulkMark([FromBody] BulkMarkAttendanceDto dto)
    {
        await _attendanceService.BulkMarkAsync(dto);
        return Ok(new { message = "Attendance recorded." });
    }
}
