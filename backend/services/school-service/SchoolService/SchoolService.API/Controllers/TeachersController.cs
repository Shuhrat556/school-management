using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Teachers;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class TeachersController : ControllerBase
{
    private readonly ITeacherService _teacherService;
    private readonly IDepartmentService _departmentService;

    public TeachersController(ITeacherService teacherService, IDepartmentService departmentService)
    {
        _teacherService = teacherService;
        _departmentService = departmentService;
    }

    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] Guid? departmentId)
    {
        if (departmentId.HasValue)
        {
            var teachers = await _teacherService.GetByDepartmentAsync(departmentId.Value);
            if (page.HasValue || pageSize.HasValue)
            {
                var paged = await _teacherService.GetByDepartmentAsync(
                    departmentId.Value, page ?? 1, pageSize ?? 20);
                return Ok(paged);
            }
            return Ok(teachers);
        }

        if (page.HasValue || pageSize.HasValue)
        {
            var paged = await _teacherService.GetAllAsync(page ?? 1, pageSize ?? 20);
            return Ok(paged);
        }
        var allTeachers = await _teacherService.GetAllAsync();
        return Ok(allTeachers);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<TeacherResponseDto>> GetById(Guid id)
    {
        var teacher = await _teacherService.GetByIdAsync(id);
        return Ok(teacher);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<TeacherResponseDto>> Create([FromBody] TeacherCreateDto dto)
    {
        var created = await _teacherService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<TeacherResponseDto>> Update(Guid id, [FromBody] TeacherUpdateDto dto)
    {
        // Admins edit any teacher; a teacher may edit only their own profile and
        // cannot change the login email, the active flag or the hire date.
        if (!User.IsInRole(Roles.Admin))
        {
            var authUserId = User.GetAuthUserId();
            var own = authUserId.HasValue && User.IsInRole(Roles.Teacher)
                ? await _teacherService.GetByAuthUserIdAsync(authUserId.Value)
                : null;
            if (own == null || own.Id != id)
                return Forbid();

            dto.Email = own.Email;
            dto.IsActive = own.IsActive;
            dto.HireDate = own.HireDate;
        }

        var updated = await _teacherService.UpdateAsync(id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _teacherService.DeleteAsync(id);
        return NoContent();
    }

    [HttpPost("{teacherId:guid}/departments/{departmentId:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AssignDepartment(Guid teacherId, Guid departmentId)
    {
        await _departmentService.AssignTeacherAsync(teacherId, departmentId);
        return Ok();
    }

    [HttpDelete("{teacherId:guid}/departments/{departmentId:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> RemoveDepartment(Guid teacherId, Guid departmentId)
    {
        await _departmentService.RemoveTeacherAsync(teacherId, departmentId);
        return NoContent();
    }
}
