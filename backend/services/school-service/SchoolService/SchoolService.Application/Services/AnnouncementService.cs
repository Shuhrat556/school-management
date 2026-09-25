using SchoolService.Application.DTOs.Announcements;
using SchoolService.Application.Exceptions;
using SchoolService.Application.Interfaces;
using SchoolService.Domain.Entities;

namespace SchoolService.Application.Services;

public class AnnouncementService : IAnnouncementService
{
    private readonly IAnnouncementRepository _repository;
    private readonly ITeacherRepository _teacherRepository;
    private readonly IClassroomRepository _classroomRepository;

    private readonly INotificationService _notifications;

    public AnnouncementService(
        IAnnouncementRepository repository,
        ITeacherRepository teacherRepository,
        IClassroomRepository classroomRepository,
        INotificationService notifications)
    {
        _repository          = repository;
        _teacherRepository   = teacherRepository;
        _classroomRepository = classroomRepository;
        _notifications       = notifications;
    }

    // Classroom announcements reach the enrolled students and their parents when first published.
    private Task NotifyPublishedAsync(Announcement a)
        => a.ClassroomId is { } classroomId
            ? _notifications.NotifyClassroomAsync(classroomId, NotificationType.Announcement,
                $"New announcement: {a.Title}", a.Body.Length > 200 ? a.Body[..200] + "…" : a.Body)
            : Task.CompletedTask;

    public async Task<IReadOnlyList<AnnouncementResponseDto>> GetAllAsync(Guid? classroomId = null)
    {
        var announcements = await _repository.GetAllAsync(classroomId);
        return announcements.Select(MapToResponse).ToList();
    }

    public async Task<AnnouncementResponseDto> GetByIdAsync(Guid id)
    {
        var a = await _repository.GetByIdAsync(id);
        if (a == null) throw new NotFoundException("Announcement", id);
        return MapToResponse(a);
    }

    public async Task<AnnouncementResponseDto> CreateAsync(AnnouncementCreateDto dto)
    {
        var teacher = await _teacherRepository.GetByIdAsync(dto.AuthorTeacherId);
        if (teacher == null) throw new NotFoundException("Teacher", dto.AuthorTeacherId);

        if (dto.ClassroomId.HasValue)
        {
            var classroom = await _classroomRepository.GetByIdAsync(dto.ClassroomId.Value);
            if (classroom == null) throw new NotFoundException("Classroom", dto.ClassroomId.Value);
        }

        var announcement = new Announcement(dto.Title, dto.Body, dto.AuthorTeacherId, dto.ClassroomId);
        if (dto.PublishImmediately) announcement.Publish();

        await _repository.AddAsync(announcement);
        if (dto.PublishImmediately)
            await NotifyPublishedAsync(announcement);

        var loaded = await _repository.GetByIdAsync(announcement.Id);
        return MapToResponse(loaded ?? announcement);
    }

    public async Task<AnnouncementResponseDto> UpdateAsync(Guid id, AnnouncementUpdateDto dto)
    {
        var a = await _repository.GetByIdAsync(id);
        if (a == null) throw new NotFoundException("Announcement", id);

        a.UpdateContent(dto.Title, dto.Body);
        await _repository.UpdateAsync(a);
        return MapToResponse(a);
    }

    public async Task<AnnouncementResponseDto> PublishAsync(Guid id)
    {
        var a = await _repository.GetByIdAsync(id);
        if (a == null) throw new NotFoundException("Announcement", id);

        var wasPublished = a.PublishedAt.HasValue;
        a.Publish();
        await _repository.UpdateAsync(a);
        if (!wasPublished)
            await NotifyPublishedAsync(a);
        return MapToResponse(a);
    }

    public async Task<AnnouncementResponseDto> UnpublishAsync(Guid id)
    {
        var a = await _repository.GetByIdAsync(id);
        if (a == null) throw new NotFoundException("Announcement", id);

        a.Unpublish();
        await _repository.UpdateAsync(a);
        return MapToResponse(a);
    }

    public async Task DeleteAsync(Guid id)
    {
        var a = await _repository.GetByIdAsync(id);
        if (a == null) throw new NotFoundException("Announcement", id);
        await _repository.DeleteAsync(a);
    }

    private static AnnouncementResponseDto MapToResponse(Announcement a) => new()
    {
        Id                = a.Id,
        Title             = a.Title,
        Body              = a.Body,
        ClassroomId       = a.ClassroomId,
        ClassroomName     = a.Classroom?.Name,
        AuthorTeacherId   = a.AuthorTeacherId,
        AuthorTeacherName = a.AuthorTeacher != null
            ? $"{a.AuthorTeacher.FirstName} {a.AuthorTeacher.LastName}" : "",
        PublishedAt       = a.PublishedAt,
        IsPublished       = a.IsPublished,
        CreatedAt         = a.CreatedAt
    };
}
