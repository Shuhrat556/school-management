using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.Application.DTOs.Rooms;
using SchoolService.Application.Interfaces;

namespace SchoolService.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class RoomsController : ControllerBase
{
    private readonly IRoomService _roomService;

    public RoomsController(IRoomService roomService)
    {
        _roomService = roomService;
    }

    [HttpGet]
    public async Task<ActionResult<List<RoomResponseDto>>> GetAll()
    {
        return await _roomService.GetAllRoomsAsync();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<RoomResponseDto>> GetById(Guid id)
    {
        var room = await _roomService.GetRoomByIdAsync(id);
        if (room == null) return NotFound();
        return room;
    }

    [Authorize(Roles = "Admin")]
    [HttpPost]
    public async Task<ActionResult<RoomResponseDto>> Create(RoomCreateDto dto)
    {
        var room = await _roomService.CreateRoomAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = room.Id }, room);
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(Guid id, RoomUpdateDto dto)
    {
        var result = await _roomService.UpdateRoomAsync(id, dto);
        if (!result) return NotFound();
        return NoContent();
    }

    [Authorize(Roles = "Admin")]
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var result = await _roomService.DeleteRoomAsync(id);
        if (!result) return NotFound();
        return NoContent();
    }
}
