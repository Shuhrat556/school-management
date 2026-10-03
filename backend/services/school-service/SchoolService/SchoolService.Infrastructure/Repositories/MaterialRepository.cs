using Microsoft.EntityFrameworkCore;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Repositories;

public class MaterialRepository : IMaterialRepository
{
    private readonly SchoolDbContext _context;

    public MaterialRepository(SchoolDbContext context)
    {
        _context = context;
    }

    public async Task<List<Material>> GetByClassroomAsync(Guid classroomId)
        => await _context.Materials
            .AsNoTracking()
            .Include(m => m.Submissions)
            .Where(m => m.ClassroomId == classroomId && m.DeletedAt == null)
            .OrderByDescending(m => m.CreatedAt)
            .ToListAsync();

    public async Task<Material?> GetByIdAsync(Guid id)
        => await _context.Materials.FindAsync(id);

    public async Task AddAsync(Material material)
    {
        await _context.Materials.AddAsync(material);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Material material)
    {
        _context.Materials.Update(material);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Material material)
    {
        _context.Materials.Remove(material);
        await _context.SaveChangesAsync();
    }
}
