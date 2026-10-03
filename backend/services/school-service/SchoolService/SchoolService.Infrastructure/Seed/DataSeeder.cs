using Microsoft.EntityFrameworkCore;
using SchoolService.Domain.Entities;
using SchoolService.Infrastructure.Data;

namespace SchoolService.Infrastructure.Seed;

// ─────────────────────────────────────────────────────────────────────────────
// University SMS Structure - CS-Focused Curriculum (2025-2026)
// ─────────────────────────────────────────────────────────────────────────────
//  3 Departments: Computer Science (primary), Business Administration,
//                 Mathematics & Science (supporting courses)
//
//  10 University Courses (Year 1-4):
//    Year 1: Java Programming, Web Dev Basics, Data Structures
//    Year 2: OOP in Java, Database Design, Web Development
//    Year 3: AI Fundamentals, System Design, Mobile Dev
//    Year 4: Capstone Project, Advanced Topics
//    + Supporting: Business Fundamentals, Discrete Math
//
//  5 Teachers: Sopheak Meas, Dara Chan, Bopha Sok, Rithy Phal, Sreyla Noun
//              Teachers 1-3: Computer Science, Teachers 4-5: Business/Math
//
//  47 Students: Distributed by Year (12/12/12/11)
//               Format: {SubjectName} {YearNumber} Y{Year}
//               Example: "Java Programming 01 Y1", "OOP in Java 02 Y2"
//
//  6 Rooms: Lecture Halls & Labs (Classroom and Lab types only)
// ─────────────────────────────────────────────────────────────────────────────

public class DataSeeder
{
    private readonly SchoolDbContext _context;

    public DataSeeder(SchoolDbContext context)
    {
        _context = context;
    }

    public async Task SeedDataAsync()
    {
        await SeedDepartmentsAsync();
        await SeedTeachersAsync();
        await SeedStudentsAsync();
        await SeedRoomsAsync();           // must come before schedules (needs room IDs)
        await SeedSubjectsAsync();        // must come before classrooms (needs subject IDs)
        await SeedClassroomsAsync();
        await SeedSchedulesAsync();
        await SeedGradesAsync();
        await SeedAttendanceAsync();
        await LinkUsersAsync();           // link teachers/students to auth service users
    }

    private async Task SeedDepartmentsAsync()
    {
        if (await _context.Departments.AnyAsync()) return;

        // 3 departments for university: CS-focused with supporting courses
        var departmentData = new[]
        {
            (Name: "Computer Science", Description: "School of Computing and Information Technology"),
            (Name: "Business Administration", Description: "School of Business & Management"),
            (Name: "Mathematics & Science", Description: "Department of Mathematics and Natural Sciences")
        };

        var departments = departmentData.Select(d => 
        {
            var dept = new Department(d.Name);
            dept.UpdateInfo(d.Name, d.Description);
            return dept;
        }).ToList();

        await _context.Departments.AddRangeAsync(departments);
        await _context.SaveChangesAsync();
    }

    private async Task SeedTeachersAsync()
    {
        if (await _context.Teachers.AnyAsync()) return;

        // 5 teachers: 3 for CS, 2 for Business/Supporting courses — Cambodian names
        var teacherData = new[]
        {
            (First: "Sopheak", Last: "Meas",  Gender: "Male",   Phone: "012-201-0001", Email: "teacher1@school.com", DepartmentName: "Computer Science"),
            (First: "Dara",    Last: "Chan",  Gender: "Male",   Phone: "012-201-0002", Email: "teacher2@school.com", DepartmentName: "Computer Science"),
            (First: "Bopha",   Last: "Sok",   Gender: "Female", Phone: "012-201-0003", Email: "teacher3@school.com", DepartmentName: "Computer Science"),
            (First: "Rithy",   Last: "Phal",  Gender: "Male",   Phone: "012-201-0004", Email: "teacher4@school.com", DepartmentName: "Business Administration"),
            (First: "Sreyla",  Last: "Noun",  Gender: "Female", Phone: "012-201-0005", Email: "teacher5@school.com", DepartmentName: "Mathematics & Science"),
        };

        var teachers = teacherData.Select(d =>
        {
            var t = new Teacher(d.First, d.Last);
            t.UpdateBasicInfo(d.First, d.Last, d.Gender, null, d.Phone, d.Email, null, null);
            return t;
        }).ToList();

        await _context.Teachers.AddRangeAsync(teachers);
        await _context.SaveChangesAsync();

        // Assign each teacher to their department
        var departments = await _context.Departments.OrderBy(d => d.Name).ToListAsync();
        var deptDict = departments.ToDictionary(d => d.Name);
        var savedTeachers = await _context.Teachers.OrderBy(t => t.Email).ToListAsync();

        for (int i = 0; i < Math.Min(teacherData.Length, savedTeachers.Count); i++)
        {
            var deptName = teacherData[i].DepartmentName;
            if (deptDict.TryGetValue(deptName, out var dept))
            {
                await _context.TeacherDepartments.AddAsync(
                    new TeacherDepartment(savedTeachers[i].Id, dept.Id)
                );
            }
        }
        await _context.SaveChangesAsync();
    }

    private async Task SeedStudentsAsync()
    {
        if (await _context.Students.AnyAsync()) return;

        // 47 Cambodian students distributed by Year
        // Year 1: students 1–12  (12 students)
        // Year 2: students 13–24 (12 students)
        // Year 3: students 25–36 (12 students)
        // Year 4: students 37–47 (11 students)
        var students = new (string First, string Last, string Email, string Gender, string Phone)[]
        {
            // ── Year 1 ────────────────────────────────────────────────────────
            ("Sokha",      "Chea",   "student1@school.com",  "Male",   "012-301-0001"),
            ("Sreymom",    "Keo",    "student2@school.com",  "Female", "012-301-0002"),
            ("Visal",      "Heng",   "student3@school.com",  "Male",   "012-301-0003"),
            ("Channary",   "Pov",    "student4@school.com",  "Female", "012-301-0004"),
            ("Dara",       "Lim",    "student5@school.com",  "Male",   "012-301-0005"),
            ("Pisey",      "Nget",   "student6@school.com",  "Female", "012-301-0006"),
            ("Raksmey",    "Sar",    "student7@school.com",  "Male",   "012-301-0007"),
            ("Sokunthea",  "Im",     "student8@school.com",  "Female", "012-301-0008"),
            ("Makara",     "Tep",    "student9@school.com",  "Male",   "012-301-0009"),
            ("Chanlina",   "Ros",    "student10@school.com", "Female", "012-301-0010"),
            ("Bunthan",    "Mok",    "student11@school.com", "Male",   "012-301-0011"),
            ("Socheata",   "Yem",    "student12@school.com", "Female", "012-301-0012"),
            // ── Year 2 ────────────────────────────────────────────────────────
            ("Vutha",      "Kang",   "student13@school.com", "Male",   "012-301-0013"),
            ("Leakena",    "Suon",   "student14@school.com", "Female", "012-301-0014"),
            ("Piseth",     "Ouk",    "student15@school.com", "Male",   "012-301-0015"),
            ("Kosal",      "Prum",   "student16@school.com", "Male",   "012-301-0016"),
            ("Sreyroth",   "Pen",    "student17@school.com", "Female", "012-301-0017"),
            ("Bunna",      "Chhim",  "student18@school.com", "Male",   "012-301-0018"),
            ("Chanpov",    "Khiev",  "student19@school.com", "Female", "012-301-0019"),
            ("Sovann",     "Nhem",   "student20@school.com", "Male",   "012-301-0020"),
            ("Reaksmey",   "Tith",   "student21@school.com", "Female", "012-301-0021"),
            ("Kimlong",    "Srey",   "student22@school.com", "Male",   "012-301-0022"),
            ("Daravy",     "Hout",   "student23@school.com", "Female", "012-301-0023"),
            ("Mengly",     "Chan",   "student24@school.com", "Male",   "012-301-0024"),
            // ── Year 3 ────────────────────────────────────────────────────────
            ("Sonika",     "Ung",    "student25@school.com", "Female", "012-301-0025"),
            ("Ratana",     "Khem",   "student26@school.com", "Male",   "012-301-0026"),
            ("Sophany",    "Loch",   "student27@school.com", "Female", "012-301-0027"),
            ("Bunthoeun",  "Meas",   "student28@school.com", "Male",   "012-301-0028"),
            ("Chanthy",    "Kem",    "student29@school.com", "Female", "012-301-0029"),
            ("Sovannara",  "Nou",    "student30@school.com", "Male",   "012-301-0030"),
            ("Kunthea",    "Sim",    "student31@school.com", "Female", "012-301-0031"),
            ("Phearak",    "Yun",    "student32@school.com", "Male",   "012-301-0032"),
            ("Thida",      "Kong",   "student33@school.com", "Female", "012-301-0033"),
            ("Sambo",      "Pich",   "student34@school.com", "Male",   "012-301-0034"),
            ("Sovannak",   "Eav",    "student35@school.com", "Male",   "012-301-0035"),
            ("Chhorvy",    "Mam",    "student36@school.com", "Female", "012-301-0036"),
            // ── Year 4 ────────────────────────────────────────────────────────
            ("Davan",      "Som",    "student37@school.com", "Male",   "012-301-0037"),
            ("Sreyleak",   "Hak",    "student38@school.com", "Female", "012-301-0038"),
            ("Naro",       "Tan",    "student39@school.com", "Male",   "012-301-0039"),
            ("Phally",     "Din",    "student40@school.com", "Female", "012-301-0040"),
            ("Sothea",     "Vong",   "student41@school.com", "Male",   "012-301-0041"),
            ("Botum",      "Ly",     "student42@school.com", "Female", "012-301-0042"),
            ("Vicheka",    "Nop",    "student43@school.com", "Male",   "012-301-0043"),
            ("Sreynich",   "San",    "student44@school.com", "Female", "012-301-0044"),
            ("Kimsan",     "Koy",    "student45@school.com", "Male",   "012-301-0045"),
            ("Chanmoly",   "Tong",   "student46@school.com", "Female", "012-301-0046"),
            ("Rithy",      "Sorn",   "student47@school.com", "Male",   "012-301-0047"),
        };

        var entities = students.Select(n =>
        {
            var s = new Student(n.First, n.Last);
            s.UpdateBasicInfo(n.First, n.Last, n.Gender, null, n.Phone, null, n.Email);
            return s;
        }).ToList();

        await _context.Students.AddRangeAsync(entities);
        await _context.SaveChangesAsync();
    }

    private async Task SeedClassroomsAsync()
    {
        if (await _context.Classrooms.AnyAsync()) return;

        var teachers = await _context.Teachers.OrderBy(t => t.Email).ToListAsync();
        var students = await _context.Students.OrderBy(s => s.Email).ToListAsync();
        var subjects = await _context.Subjects.OrderBy(s => s.SubjectName).ToListAsync();
        var rooms = await _context.Rooms.OrderBy(r => r.Name).ToListAsync();

        if (teachers.Count < 5 || students.Count < 47 || subjects.Count < 10 || rooms.Count == 0) return;
        
        // 12 course sections: 10 CS courses + 2 supporting
        // Format: {SubjectName} {YearNumber} Y{Year}
        // All courses in Year N use the same year number (01 for Y1, 02 for Y2, etc.)
        var courseData = new[]
        {
            // Year 1 courses (3 subjects, all use "01 Y1")
            (Name: "Java Programming 01 Y1", TeacherIdx: 0, SubjectIdx: 0, StudentStart:  0, StudentCount: 4, Year: 1),
            (Name: "Web Dev Basics 01 Y1", TeacherIdx: 1, SubjectIdx: 1, StudentStart:  4, StudentCount: 4, Year: 1),
            (Name: "Data Structures 01 Y1", TeacherIdx: 2, SubjectIdx: 2, StudentStart:  8, StudentCount: 3, Year: 1),
            (Name: "Business Fundamentals 01 Y1", TeacherIdx: 3, SubjectIdx: 10, StudentStart: 11, StudentCount: 2, Year: 1),
            
            // Year 2 courses (3 subjects, all use "02 Y2")
            (Name: "OOP in Java 02 Y2", TeacherIdx: 0, SubjectIdx: 3, StudentStart: 13, StudentCount: 3, Year: 2),
            (Name: "Database Design 02 Y2", TeacherIdx: 1, SubjectIdx: 4, StudentStart: 16, StudentCount: 4, Year: 2),
            (Name: "Web Development 02 Y2", TeacherIdx: 2, SubjectIdx: 5, StudentStart: 20, StudentCount: 4, Year: 2),
            
            // Year 3 courses (2 subjects, all use "03 Y3")
            (Name: "AI Fundamentals 03 Y3", TeacherIdx: 0, SubjectIdx: 6, StudentStart: 24, StudentCount: 4, Year: 3),
            (Name: "System Design 03 Y3", TeacherIdx: 1, SubjectIdx: 7, StudentStart: 28, StudentCount: 4, Year: 3),
            
            // Year 4 courses (2 subjects, all use "04 Y4")
            (Name: "Capstone Project 04 Y4", TeacherIdx: 2, SubjectIdx: 8, StudentStart: 32, StudentCount: 4, Year: 4),
            (Name: "Advanced Topics 04 Y4", TeacherIdx: 4, SubjectIdx: 9, StudentStart: 36, StudentCount: 4, Year: 4),
            
            // Supporting Year 1 course
            (Name: "Discrete Mathematics 01 Y1", TeacherIdx: 4, SubjectIdx: 11, StudentStart: 40, StudentCount: 7, Year: 1),
        };

        var enrollments = new List<StudentClassroom>();

        foreach (var cd in courseData)
        {
            // Create course section as a classroom with new naming format
            var cls = new Classroom(cd.Name, subjects[cd.SubjectIdx].Id);
            // Set grade to Year 1, Year 2, Year 3, Year 4 based on course year level
            var gradeLabel = $"Year {cd.Year}";
            cls.UpdateInfo(cd.Name, gradeLabel, "Semester 1 2025-2026", null, rooms[(courseData.ToList().IndexOf(cd)) % rooms.Count].Id);
            cls.AssignTeacher(teachers[cd.TeacherIdx].Id);
            await _context.Classrooms.AddAsync(cls);
            await _context.SaveChangesAsync();

            // Enroll students
            for (int si = 0; si < cd.StudentCount; si++)
            {
                int idx = cd.StudentStart + si;
                if (idx < students.Count)
                    enrollments.Add(new StudentClassroom(students[idx].Id, cls.Id));
            }
        }

        await _context.StudentClassrooms.AddRangeAsync(enrollments);
        await _context.SaveChangesAsync();
    }

    private async Task SeedSubjectsAsync()
    {
        if (await _context.Subjects.AnyAsync()) return;

        var departments = await _context.Departments.OrderBy(d => d.Name).ToListAsync();
        if (departments.Count < 3) return;

        // 10 university courses: 8 CS-focused + 2 supporting (80/20 ratio)
        // Courses include year level tracking
        // Note: departments ordered alphabetically: Business Admin (0), Computer Science (1), Math & Science (2)
        var courseData = new[]
        {
            // Year 1 (3 courses)
            (Code: "CS101Y1", Name: "Java Programming", DeptIdx: 1, Year: 1),
            (Code: "CS102Y1", Name: "Web Dev Basics", DeptIdx: 1, Year: 1),
            (Code: "CS103Y1", Name: "Data Structures", DeptIdx: 1, Year: 1),
            
            // Year 2 (3 courses)
            (Code: "CS201Y2", Name: "OOP in Java", DeptIdx: 1, Year: 2),
            (Code: "CS202Y2", Name: "Database Design", DeptIdx: 1, Year: 2),
            (Code: "CS203Y2", Name: "Web Development", DeptIdx: 1, Year: 2),
            
            // Year 3 (2 courses)
            (Code: "CS301Y3", Name: "AI Fundamentals", DeptIdx: 1, Year: 3),
            (Code: "CS302Y3", Name: "System Design", DeptIdx: 1, Year: 3),
            
            // Year 4 (2 courses)
            (Code: "CS401Y4", Name: "Capstone Project", DeptIdx: 1, Year: 4),
            (Code: "CS402Y4", Name: "Advanced Topics", DeptIdx: 1, Year: 4),
            
            // Supporting courses (non-CS, ~20%)
            (Code: "BUS101", Name: "Business Fundamentals", DeptIdx: 0, Year: 1),
            (Code: "MATH101", Name: "Discrete Mathematics", DeptIdx: 2, Year: 1),
        };

        var subjects = courseData.Select(c => 
        {
            var category = c.DeptIdx == 0 || c.DeptIdx == 2
                ? "Foundations"
                : c.Year >= 3 ? "Advanced" : "Core CS";
            var subject = new Subject(c.Name, departments[c.DeptIdx].Id, category, null, c.Code);
            return subject;
        }).ToList();

        await _context.Subjects.AddRangeAsync(subjects);
        await _context.SaveChangesAsync();

        // Assign teachers to subjects
        var teachers = await _context.Teachers.OrderBy(t => t.Email).ToListAsync();
        if (teachers.Count >= 5)
        {
            // Teacher 1 (CS): CS101Y1, CS201Y2, CS301Y3
            // Teacher 2 (CS): CS102Y1, CS202Y2, CS302Y3
            // Teacher 3 (CS): CS103Y1, CS203Y2, CS401Y4
            // Teacher 4 (Business): BUS101
            // Teacher 5 (Math): CS402Y4, MATH101
            var teacherAssignments = new[]
            {
                new[] { 0, 3, 6 },        // teacher1 → CS101Y1, CS201Y2, CS301Y3
                new[] { 1, 4, 7 },        // teacher2 → CS102Y1, CS202Y2, CS302Y3
                new[] { 2, 5, 8 },        // teacher3 → CS103Y1, CS203Y2, CS401Y4
                new[] { 10 },             // teacher4 → BUS101
                new[] { 9, 11 }           // teacher5 → CS402Y4, MATH101
            };

            for (int t = 0; t < Math.Min(5, teachers.Count); t++)
            {
                foreach (int s in teacherAssignments[t])
                {
                    if (s < subjects.Count)
                        await _context.TeacherSubjects.AddAsync(new TeacherSubject(teachers[t].Id, subjects[s].Id));
                }
            }
            await _context.SaveChangesAsync();
        }
    }

    private async Task SeedSchedulesAsync()
    {
        if (await _context.Schedules.AnyAsync()) return;

        var classrooms = await _context.Classrooms.OrderBy(c => c.Name).ToListAsync();
        var subjects   = await _context.Subjects.OrderBy(s => s.SubjectName).ToListAsync();
        var teachers   = await _context.Teachers.OrderBy(t => t.Email).ToListAsync();
        var rooms      = await _context.Rooms.OrderBy(r => r.Name).ToListAsync();

        if (classrooms.Count < 10 || subjects.Count < 10 || teachers.Count < 5 || rooms.Count < 6) return;

        // Map course sections to their subjects
        var classroomToSubject = new Dictionary<Guid, Subject>();
        for (int i = 0; i < Math.Min(classrooms.Count, subjects.Count); i++)
        {
            classroomToSubject[classrooms[i].Id] = subjects[i];
        }

        // Weekly university schedule: 2 slots per day (9:00-10:30, 11:00-12:30), 5 days/week
        // Each course section gets one time slot assigned
        var timeSlots = new[]
        {
            (Day: SchoolDayOfWeek.Monday,    Start: new TimeOnly(9,  0), End: new TimeOnly(10, 30), RoomIdx: 0),
            (Day: SchoolDayOfWeek.Monday,    Start: new TimeOnly(11, 0), End: new TimeOnly(12, 30), RoomIdx: 1),
            (Day: SchoolDayOfWeek.Tuesday,   Start: new TimeOnly(9,  0), End: new TimeOnly(10, 30), RoomIdx: 2),
            (Day: SchoolDayOfWeek.Tuesday,   Start: new TimeOnly(11, 0), End: new TimeOnly(12, 30), RoomIdx: 3),
            (Day: SchoolDayOfWeek.Wednesday, Start: new TimeOnly(9,  0), End: new TimeOnly(10, 30), RoomIdx: 4),
            (Day: SchoolDayOfWeek.Wednesday, Start: new TimeOnly(11, 0), End: new TimeOnly(12, 30), RoomIdx: 5),
            (Day: SchoolDayOfWeek.Thursday,  Start: new TimeOnly(9,  0), End: new TimeOnly(10, 30), RoomIdx: 0),
            (Day: SchoolDayOfWeek.Thursday,  Start: new TimeOnly(11, 0), End: new TimeOnly(12, 30), RoomIdx: 1),
            (Day: SchoolDayOfWeek.Friday,    Start: new TimeOnly(9,  0), End: new TimeOnly(10, 30), RoomIdx: 2),
            (Day: SchoolDayOfWeek.Friday,    Start: new TimeOnly(11, 0), End: new TimeOnly(12, 30), RoomIdx: 3),
        };

        // Assign each course section to a time slot (prefer labs for CS practical courses)
        for (int i = 0; i < classrooms.Count; i++)
        {
            var classroom = classrooms[i];
            if (!classroomToSubject.TryGetValue(classroom.Id, out var subject)) continue;

            var slot = timeSlots[i % timeSlots.Length];
            var room = rooms[slot.RoomIdx % rooms.Count];
            var teacher = teachers[i % teachers.Count];

            var schedule = new Schedule(
                classroom.Id,
                subject.Id,
                teacher.Id,
                slot.Day,
                slot.Start,
                slot.End);
            
            await _context.Schedules.AddAsync(schedule);
        }

        await _context.SaveChangesAsync();
    }

    private async Task SeedGradesAsync()
    {
        if (await _context.StudentGrades.AnyAsync()) return;

        var students = await _context.Students.ToListAsync();
        var subjects = await _context.Subjects.ToListAsync();

        if (students.Count == 0 || subjects.Count == 0) return;

        var rng = new Random(42);
        foreach (var student in students)
        {
            // Give every student a grade for every subject
            foreach (var subject in subjects)
            {
                var score = Math.Round((decimal)(rng.NextDouble() * 40 + 60), 2); // 60–100
                // Grade label includes semester context
                var grade = new StudentGrade(student.Id, subject.Id, score, "Semester 1 2025-2026");
                await _context.StudentGrades.AddAsync(grade);
            }
        }

        await _context.SaveChangesAsync();
    }

    private async Task SeedAttendanceAsync()
    {
        if (await _context.Attendances.AnyAsync()) return;

        // Load each classroom with its enrolled students
        var classrooms = await _context.Classrooms.ToListAsync();
        var enrollments = await _context.StudentClassrooms.ToListAsync();

        if (classrooms.Count == 0 || enrollments.Count == 0) return;

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var statuses = new[] { AttendanceStatus.Present, AttendanceStatus.Present, AttendanceStatus.Late, AttendanceStatus.Absent };
        var rng = new Random(99);

        foreach (var classroom in classrooms)
        {
            var studentIds = enrollments
                .Where(e => e.ClassroomId == classroom.Id)
                .Select(e => e.StudentId)
                .ToList();

            for (int day = 0; day < 5; day++)
            {
                var date = today.AddDays(-day);
                for (int si = 0; si < studentIds.Count; si++)
                {
                    var status = statuses[(day + si) % statuses.Length];
                    await _context.Attendances.AddAsync(
                        new Attendance(studentIds[si], classroom.Id, date, status));
                }
            }
        }

        await _context.SaveChangesAsync();
    }

    private async Task SeedRoomsAsync()
    {
        if (await _context.Rooms.AnyAsync()) return;

        // 6 university rooms for lectures and labs (Classroom and Lab types only)
        var roomData = new[]
        {
            (Name: "Lecture Hall 1 - Main Building", Building: "Main Building", Capacity: 40, Floor: 1, Type: RoomType.Classroom),
            (Name: "Lecture Hall 2 - Main Building", Building: "Main Building", Capacity: 35, Floor: 2, Type: RoomType.Classroom),
            (Name: "Tutorial Room 101 - Science Building", Building: "Science Building", Capacity: 20, Floor: 1, Type: RoomType.Classroom),
            (Name: "CS Lab A - Tech Building", Building: "Tech Building", Capacity: 30, Floor: 1, Type: RoomType.Lab),
            (Name: "CS Lab B - Tech Building", Building: "Tech Building", Capacity: 25, Floor: 2, Type: RoomType.Lab),
            (Name: "Computer Lab - Main Building", Building: "Main Building", Capacity: 28, Floor: 3, Type: RoomType.Lab),
        };

        var rooms = roomData.Select(r =>
        {
            var room = new Room(r.Name, r.Building, r.Capacity, r.Type);
            return room;
        }).ToList();

        await _context.Rooms.AddRangeAsync(rooms);
        await _context.SaveChangesAsync();
    }

    private async Task LinkUsersAsync()
    {
        // Link Teachers and Students to their Auth Service users by email
        // This bridges the two separate databases (School DB and Auth DB)
        
        var teachers = await _context.Teachers.Where(t => t.AuthUserId == null).ToListAsync();
        var students = await _context.Students.Where(s => s.AuthUserId == null).ToListAsync();

        if (teachers.Count == 0 && students.Count == 0) return;

        try
        {
            // Note: In a real scenario, you would query the Auth DB directly.
            // For now, we're creating a reference structure.
            // The actual linking happens through the email matching:
            // teacher1@school.com → Auth User with same email
            // student1@school.com → Auth User with same email
            
            // Update: Link by email pattern
            foreach (var teacher in teachers)
            {
                if (teacher.Email != null && teacher.Email.StartsWith("teacher"))
                {
                    // In production, query Auth DB for User with this email
                    // For demo: Set a placeholder. Actual linking done via migration or separate sync process.
                    // teacher.SetAuthUserId(authUserId);  // Once fetched from Auth DB
                }
            }

            foreach (var student in students)
            {
                if (student.Email != null && student.Email.StartsWith("student"))
                {
                    // In production, query Auth DB for User with this email
                    // For demo: Set a placeholder. Actual linking done via migration or separate sync process.
                    // student.SetAuthUserId(authUserId);  // Once fetched from Auth DB
                }
            }

            // In a real multi-database scenario, you would need to:
            // 1. Use a second DbContext for Auth DB
            // 2. Query Auth users by email
            // 3. Match and update here
            // For now, this method is a placeholder for the linking logic.
            // The actual implementation depends on your Auth DB configuration.
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Could not link users to auth service: {ex.Message}");
        }
    }
}
