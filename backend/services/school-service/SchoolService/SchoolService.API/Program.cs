using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using SchoolService.Application.Interfaces;
using SchoolService.Application.Services;
using SchoolService.Infrastructure.Data;
using SchoolService.Infrastructure.Repositories;
using SchoolService.Infrastructure.Seed;
using SchoolService.API.Services;
using SchoolService.API.Middleware;
using System.Net;
using System.Text;
using System.Text.Json;
using Consul;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        // Shape validation errors to match the standard error response format
        options.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .SelectMany(e => e.Value!.Errors.Select(er => er.ErrorMessage))
                .ToList();

            var traceId = System.Diagnostics.Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;

            var response = new
            {
                message = "Validation failed.",
                code = "VALIDATION_ERROR",
                details = string.Join(" ", errors),
                traceId,
                statusCode = 400,
                path = context.HttpContext.Request.Path.Value
            };

            return new BadRequestObjectResult(response);
        };
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Paste the accessToken from POST /api/auth/authenticate"
    });
    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = []
    });
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

builder.Services.AddSingleton<IConsulClient, ConsulClient>(sp => new ConsulClient(cfg =>
{
    var consulHost = builder.Configuration["consul:host"] ?? "localhost";
    var consulPort = int.TryParse(builder.Configuration["consul:port"], out var p) ? p : 8500;
    cfg.Address = new Uri($"http://{consulHost}:{consulPort}");
}));

builder.Services.AddMemoryCache();
builder.Services.AddSingleton<IServiceDiscoveryClient, ServiceDiscoveryClient>();

builder.Services.AddDbContext<SchoolDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("SchoolDb")));

builder.Services.AddHttpClient();
builder.Services.AddScoped<IAuthServiceClient, AuthServiceClient>();

builder.Services.AddScoped<IClassroomRepository, ClassroomRepository>();
builder.Services.AddScoped<IStudentRepository, StudentRepository>();
builder.Services.AddScoped<ITeacherRepository, TeacherRepository>();
builder.Services.AddScoped<IDepartmentRepository, DepartmentRepository>();
builder.Services.AddScoped<ISubjectRepository, SubjectRepository>();
builder.Services.AddScoped<IAttendanceRepository, AttendanceRepository>();
builder.Services.AddScoped<IScheduleRepository, ScheduleRepository>();
builder.Services.AddScoped<IRoomRepository, RoomRepository>();
builder.Services.AddScoped<IMaterialRepository, MaterialRepository>();
builder.Services.AddScoped<ISubmissionRepository, SubmissionRepository>();
builder.Services.AddScoped<IGradeRepository, GradeRepository>();
builder.Services.AddScoped<IAnnouncementRepository, AnnouncementRepository>();

// Service Registrations
builder.Services.AddScoped<IClassroomService, ClassroomService>();
builder.Services.AddScoped<ITeacherService, TeacherService>();
builder.Services.AddScoped<IDepartmentService, DepartmentService>();
builder.Services.AddScoped<ISubjectService, SubjectService>();
builder.Services.AddScoped<IStudentService, StudentService>();
builder.Services.AddScoped<IAttendanceService, AttendanceService>();
builder.Services.AddScoped<IScheduleService, ScheduleService>();
builder.Services.AddScoped<IRoomService, RoomService>();
builder.Services.AddScoped<IMaterialService, MaterialService>();
builder.Services.AddScoped<ISubmissionService, SubmissionService>();
builder.Services.AddScoped<IGradeService, GradeService>();
builder.Services.AddScoped<IAnnouncementService, AnnouncementService>();
builder.Services.AddScoped<DataSeeder>();

var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtSecret = (!string.IsNullOrEmpty(jwtSection["Secret"]) ? jwtSection["Secret"] : null) 
             ?? (!string.IsNullOrEmpty(builder.Configuration["Jwt__Secret"]) ? builder.Configuration["Jwt__Secret"] : null)
             ?? (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("JWT_SECRET")) ? Environment.GetEnvironmentVariable("JWT_SECRET") : null)
             ?? "your-secret-key-change-me-in-production-this-is-insecure";
var key = Encoding.UTF8.GetBytes(jwtSecret);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = jwtSection["Issuer"],
        ValidateAudience = true,
        ValidAudience = jwtSection["Audience"],
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(1)
    };
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<SchoolDbContext>();

    var dbMaxAttempts = 10;
    var dbDelay = TimeSpan.FromSeconds(2);
    for (int attempt = 1; attempt <= dbMaxAttempts; attempt++)
    {
        try
        {
            var connection = db.Database.GetDbConnection();
            await connection.OpenAsync();
            await connection.CloseAsync();

            db.Database.EnsureCreated();

            // Apply schema additions that aren't tracked by migrations (EnsureCreated doesn't run migrations)
            await db.Database.ExecuteSqlRawAsync(@"
                ALTER TABLE ""Teachers"" ADD COLUMN IF NOT EXISTS ""AuthUserId"" uuid;
                ALTER TABLE ""Students"" ADD COLUMN IF NOT EXISTS ""AuthUserId"" uuid;
                CREATE UNIQUE INDEX IF NOT EXISTS ""IX_Teachers_AuthUserId""
                    ON ""Teachers""(""AuthUserId"") WHERE ""AuthUserId"" IS NOT NULL;
                CREATE UNIQUE INDEX IF NOT EXISTS ""IX_Students_AuthUserId""
                    ON ""Students""(""AuthUserId"") WHERE ""AuthUserId"" IS NOT NULL;

                CREATE TABLE IF NOT EXISTS ""Rooms"" (
                    ""Id"" uuid NOT NULL,
                    ""Name"" character varying(150) NOT NULL,
                    ""Location"" character varying(500),
                    ""Capacity"" integer NOT NULL DEFAULT 0,
                    ""Type"" integer NOT NULL,
                    ""IsActive"" boolean NOT NULL,
                    ""CreatedAt"" timestamp with time zone NOT NULL,
                    ""DeletedAt"" timestamp with time zone,
                    CONSTRAINT ""PK_Rooms"" PRIMARY KEY (""Id"")
                );

                ALTER TABLE ""Classrooms"" ADD COLUMN IF NOT EXISTS ""RoomId"" uuid;
                ALTER TABLE ""Classrooms"" ADD COLUMN IF NOT EXISTS ""Semester"" character varying(20);
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM pg_constraint
                        WHERE conname = 'FK_Classrooms_Rooms_RoomId'
                    ) THEN
                        ALTER TABLE ""Classrooms""
                        ADD CONSTRAINT ""FK_Classrooms_Rooms_RoomId""
                        FOREIGN KEY (""RoomId"") REFERENCES ""Rooms""(""Id"") ON DELETE SET NULL;
                    END IF;
                END $$;
                CREATE INDEX IF NOT EXISTS ""IX_Classrooms_RoomId"" ON ""Classrooms""(""RoomId"");

                CREATE TABLE IF NOT EXISTS ""Announcements"" (
                    ""Id"" uuid NOT NULL,
                    ""Title"" character varying(200) NOT NULL,
                    ""Body"" text NOT NULL,
                    ""ClassroomId"" uuid,
                    ""AuthorTeacherId"" uuid NOT NULL,
                    ""PublishedAt"" timestamp with time zone,
                    ""CreatedAt"" timestamp with time zone NOT NULL,
                    CONSTRAINT ""PK_Announcements"" PRIMARY KEY (""Id"")
                );
                CREATE INDEX IF NOT EXISTS ""IX_Announcements_ClassroomId"" ON ""Announcements""(""ClassroomId"");
                CREATE INDEX IF NOT EXISTS ""IX_Announcements_AuthorTeacherId"" ON ""Announcements""(""AuthorTeacherId"");

                CREATE TABLE IF NOT EXISTS ""Materials"" (
                    ""Id"" uuid NOT NULL,
                    ""ClassroomId"" uuid NOT NULL,
                    ""Title"" character varying(200) NOT NULL,
                    ""Description"" text,
                    ""Url"" character varying(1000),
                    ""Type"" integer NOT NULL,
                    ""IsActive"" boolean NOT NULL,
                    ""CreatedAt"" timestamp with time zone NOT NULL,
                    ""DeletedAt"" timestamp with time zone,
                    CONSTRAINT ""PK_Materials"" PRIMARY KEY (""Id"")
                );
                CREATE INDEX IF NOT EXISTS ""IX_Materials_ClassroomId"" ON ""Materials""(""ClassroomId"");

                CREATE TABLE IF NOT EXISTS ""Submissions"" (
                    ""Id"" uuid NOT NULL,
                    ""MaterialId"" uuid NOT NULL,
                    ""StudentId"" uuid NOT NULL,
                    ""SubmissionUrl"" character varying(1000),
                    ""SubmittedAt"" timestamp with time zone NOT NULL,
                    ""Grade"" numeric(5,2),
                    ""Feedback"" text,
                    CONSTRAINT ""PK_Submissions"" PRIMARY KEY (""Id"")
                );
                CREATE INDEX IF NOT EXISTS ""IX_Submissions_MaterialId"" ON ""Submissions""(""MaterialId"");
                CREATE INDEX IF NOT EXISTS ""IX_Submissions_StudentId"" ON ""Submissions""(""StudentId"");
            ");

            var seeder = scope.ServiceProvider.GetRequiredService<DataSeeder>();
            await seeder.SeedDataAsync();

            Console.WriteLine("Database is ready.");
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Attempt {attempt} to connect to database failed: {ex.Message}");
            if (attempt == dbMaxAttempts)
                throw;

            await Task.Delay(dbDelay);
            dbDelay = TimeSpan.FromSeconds(dbDelay.TotalSeconds * 2);
        }
    }
}

app.UseMiddleware<GlobalExceptionMiddleware>();

if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "school-service" }))
   .AllowAnonymous();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

_ = Task.Run(async () =>
{
    var consulClient = app.Services.GetRequiredService<IConsulClient>();
    var registration = new AgentServiceRegistration()
    {
        ID = "school-service-" + Guid.NewGuid().ToString(),
        Name = builder.Configuration["spring:application:name"] ?? "school-service",
        Address = "school-service",
        Port = 8080,
        Tags = new[] { "school", "api" },
        Check = new AgentServiceCheck
        {
            HTTP = "http://school-service:8080/health",
            Interval = TimeSpan.FromSeconds(10),
            DeregisterCriticalServiceAfter = TimeSpan.FromMinutes(1)
        }
    };

    var maxAttempts = 10;
    var delay = TimeSpan.FromSeconds(3);
    for (int attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            await consulClient.Agent.ServiceRegister(registration);
            Console.WriteLine("SchoolService registered with Consul.");

            app.Lifetime.ApplicationStopping.Register(async () =>
            {
                try
                {
                    await consulClient.Agent.ServiceDeregister(registration.ID);
                    Console.WriteLine("SchoolService deregistered from Consul.");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to deregister from Consul: {ex.Message}");
                }
            });
            break;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Attempt {attempt} to register with Consul failed: {ex.Message}");
            if (attempt == maxAttempts)
            {
                Console.WriteLine("Could not register with Consul, continuing without it.");
                break;
            }
            await Task.Delay(delay);
        }
    }
});

app.Run();

