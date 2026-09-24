using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Authorization;
using SchoolService.Application.DTOs.Materials;
using SchoolService.Application.Services;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class MaterialsController : ControllerBase
{
    private readonly MaterialService _materialService;

    public MaterialsController(MaterialService materialService)
    {
        _materialService = materialService;
    }

    [HttpGet("classroom/{classroomId}")]
    public async Task<ActionResult<List<MaterialResponseDto>>> GetByClassroom(Guid classroomId)
    {
        return await _materialService.GetMaterialsByClassroomAsync(classroomId);
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
