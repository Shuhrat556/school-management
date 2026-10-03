namespace SchoolService.Application.Interfaces;

// Which classes and students a teacher teaches: classes where they are the class teacher
// or on the timetable, and the students currently enrolled in them.
public interface ITeachingRepository
{
    Task<bool> TeachesClassroomAsync(Guid teacherId, Guid classroomId);
    Task<bool> TeachesStudentAsync(Guid teacherId, Guid studentId);
}
