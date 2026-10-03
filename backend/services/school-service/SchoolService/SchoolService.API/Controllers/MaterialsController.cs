using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Materials;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class MaterialsController : ControllerBase
{
    private readonly IMaterialService _materialService;

    private readonly ProfileAccess _access;

    public MaterialsController(IMaterialService materialService, ProfileAccess access)
    {
        _materialService = materialService;
        _access = access;
    }

    [HttpGet("classroom/{classroomId}")]
    public async Task<ActionResult<List<MaterialResponseDto>>> GetByClassroom(Guid classroomId)
    {
        if (!await _access.CanAccessClassroomAsync(User, classroomId))
            return Forbid();
        return await _materialService.GetMaterialsByClassroomAsync(classroomId, includeInactive: User.IsStaff());
    }

    [HttpPost]
    [Authorize(Roles = Roles.Staff)]
    public async Task<ActionResult<MaterialResponseDto>> Create(MaterialCreateDto dto)
    {
        var material = await _materialService.CreateMaterialAsync(dto);
        return Ok(material);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Update(Guid id, MaterialUpdateDto dto)
    {
        var result = await _materialService.UpdateMaterialAsync(id, dto);
        if (!result) return NotFound();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = Roles.Staff)]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await _materialService.DeleteMaterialAsync(id);
        if (!result) return NotFound();
        return NoContent();
    }
}
