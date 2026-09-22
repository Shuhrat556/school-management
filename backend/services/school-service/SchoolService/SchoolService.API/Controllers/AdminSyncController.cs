using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/school/admin")]
public class AdminSyncController : ControllerBase
{
    private readonly ITeacherRepository _teacherRepo;
    private readonly IStudentRepository _studentRepo;

    public AdminSyncController(ITeacherRepository teacherRepo, IStudentRepository studentRepo)
    {
        _teacherRepo = teacherRepo;
        _studentRepo = studentRepo;
    }

    [HttpPost("sync-profile")]
    public async Task<IActionResult> SyncProfile([FromBody] SyncProfileRequest req)
    {
        if (req.AuthUserId == Guid.Empty)
            return BadRequest(new { error = "AuthUserId is required." });

        switch (req.Role)
        {
            case 1: // Teacher
            {
                var existing = await _teacherRepo.GetByAuthUserIdAsync(req.AuthUserId);
                if (existing == null)
                {
                    var teacher = new Teacher(req.FirstName, req.LastName, req.AuthUserId);
                    await _teacherRepo.AddAsync(teacher);
                    return Ok(new { created = true, entity = "Teacher", id = teacher.Id });
                }
                return Ok(new { created = false, entity = "Teacher", id = existing.Id });
            }
            case 2: // Student
            {
                var existing = await _studentRepo.GetByAuthUserIdAsync(req.AuthUserId);
                if (existing == null)
                {
                    var student = new Student(req.FirstName, req.LastName, req.AuthUserId);
                    await _studentRepo.AddAsync(student);
                    return Ok(new { created = true, entity = "Student", id = student.Id });
                }
                return Ok(new { created = false, entity = "Student", id = existing.Id });
            }
            default: // Parent (3), Admin (4) — no school profile needed
                return Ok(new { created = false, entity = (string?)null });
        }
    }
}

public class SyncProfileRequest
{
    public Guid AuthUserId { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public int Role { get; set; }
}
