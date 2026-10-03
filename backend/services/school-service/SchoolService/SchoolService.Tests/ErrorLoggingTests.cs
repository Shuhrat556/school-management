using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SchoolService.Tests.Infrastructure;

namespace SchoolService.Tests;

// A client mistake (400/404/409) is a normal outcome, not an "unhandled exception":
// logging it as an error with a stack trace buries real failures in production logs.
public class ErrorLoggingTests
{
    private sealed class CapturingLoggerProvider : ILoggerProvider
    {
        public ConcurrentBag<(string Category, LogLevel Level, Exception? Exception)> Entries { get; } = new();

        public ILogger CreateLogger(string categoryName) => new Logger(categoryName, Entries);
        public void Dispose() { }

        private sealed class Logger(string category, ConcurrentBag<(string, LogLevel, Exception?)> entries) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
            public bool IsEnabled(LogLevel logLevel) => true;
            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
                => entries.Add((category, logLevel, exception));
        }
    }

    private sealed class LoggingFactory : SchoolApiFactory
    {
        public CapturingLoggerProvider Logs { get; } = new();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureTestServices(services => services.AddSingleton<ILoggerProvider>(Logs));
        }
    }

    [Fact]
    public async Task Client_errors_are_not_logged_as_errors()
    {
        using var factory = new LoggingFactory();

        var response = await factory.CreateClientAs("Admin").GetAsync($"/api/school/students/{Guid.NewGuid()}/report-card");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var middleware = factory.Logs.Entries.Where(e => e.Category.EndsWith("GlobalExceptionMiddleware")).ToList();
        Assert.NotEmpty(middleware);
        Assert.All(middleware, e => Assert.True(e.Level < LogLevel.Warning && e.Exception == null, $"{e.Level} {e.Exception?.GetType().Name}"));
    }
}
