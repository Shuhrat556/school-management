using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs;
using SchoolService.Application.DTOs.Classrooms;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Route("api/school/[controller]")]
[Authorize]
public class ClassroomsController : ControllerBase
{
    private readonly IClassroomService _classroomService;
    private readonly ProfileAccess _access;

    public ClassroomsController(IClassroomService classroomService, ProfileAccess access)
    {
        _classroomService = classroomService;
        _access = access;
    }

    [HttpGet]
    public async Task<ActionResult> GetAll(
        [FromQuery] int? page,
        [FromQuery] int? pageSize)
    {
        // Students and parents see their own (children's) classes only
        if (await _access.GetVisibleClassroomIdsAsync(User) is { } visible)
            return Ok((await _classroomService.GetAllAsync()).Where(c => visible.Contains(c.Id)).ToList());

        if (page.HasValue || pageSize.HasValue)
        {
            var paged = await _classroomService.GetAllAsync(page ?? 1, pageSize ?? 20);
            return Ok(paged);
        }
        var classrooms = await _classroomService.GetAllAsync();
        return Ok(classrooms);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ClassroomDetailResponseDto>> GetById(Guid id)
    {
        if (!await _access.CanAccessClassroomAsync(User, id))
            return Forbid();

        var classroom = await _classroomService.GetByIdAsync(id);
        if (!User.IsStaff())
        {
            // Classmates see each other's names only, never contact details or birthdays
            foreach (var student in classroom.Students)
            {
                student.Email = null;
                student.Phone = null;
                student.Gender = null;
                student.DateOfBirth = null;
            }
        }
        return Ok(classroom);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<ClassroomResponseDto>> Create([FromBody] ClassroomCreateDto dto)
    {
        var created = await _classroomService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<ClassroomResponseDto>> Update(Guid id, [FromBody] ClassroomUpdateDto dto)
    {
        var updated = await _classroomService.UpdateAsync(id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> Delete(Guid id)
    {
        await _classroomService.DeleteAsync(id);
        return NoContent();
    }

    [HttpPost("{id:guid}/enroll")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> EnrollStudent(Guid id, [FromBody] EnrollStudentDto dto)
    {
        await _classroomService.EnrollStudentAsync(id, dto.StudentId);
        return Ok(new { message = "Student enrolled successfully." });
    }

    [HttpDelete("{id:guid}/unenroll/{studentId:guid}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> UnenrollStudent(Guid id, Guid studentId)
    {
        await _classroomService.UnenrollStudentAsync(id, studentId);
        return NoContent();
    }
}
