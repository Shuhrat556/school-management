using System.Diagnostics;
using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SchoolService.Application.Exceptions;

namespace SchoolService.API.Middleware;

public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;
    private readonly IWebHostEnvironment _environment;

    public GlobalExceptionMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionMiddleware> logger,
        IWebHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception exception)
        {
            var traceId = Activity.Current?.Id ?? context.TraceIdentifier;
            var response = MapException(exception, traceId, _environment.IsDevelopment());

            // A 4xx is the client's mistake (validation, not found, conflict): an ordinary outcome, logged
            // briefly. Only server faults are errors with a stack trace, so real failures stand out.
            if (response.statusCode >= 500)
                _logger.LogError(
                    exception,
                    "Unhandled exception for {Method} {Path}. TraceId: {TraceId}",
                    context.Request.Method,
                    context.Request.Path,
                    traceId);
            else
                _logger.LogInformation(
                    "{Method} {Path} answered {StatusCode} {Code}: {Message}. TraceId: {TraceId}",
                    context.Request.Method,
                    context.Request.Path,
                    response.statusCode,
                    response.code,
                    exception.Message,
                    traceId);

            await WriteResponseAsync(context, response);
        }
    }

    private static Task WriteResponseAsync(HttpContext context, ErrorResponse response)
    {
        context.Response.ContentType = "application/json";

        response.path = context.Request.Path.Value;
        context.Response.StatusCode = response.statusCode;

        return context.Response.WriteAsJsonAsync(response);
    }

    private static ErrorResponse MapException(Exception exception, string traceId, bool includeDebugDetails)
    {
        var response = new ErrorResponse
        {
            message = "An unexpected server error occurred.",
            code = "INTERNAL_ERROR",
            traceId = traceId,
            statusCode = (int)HttpStatusCode.InternalServerError,
            path = null,
        };

        switch (exception)
        {
            case NotFoundException ex:
                response.statusCode = (int)HttpStatusCode.NotFound;
                response.message = ex.Message;
                response.code = "NOT_FOUND";
                response.details = ex.Message;
                break;

            case ValidationException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = ex.Message;
                response.code = "VALIDATION_ERROR";
                response.details = ex.Message;
                break;

            case DuplicateException ex:
                response.statusCode = (int)HttpStatusCode.Conflict;
                response.message = ex.Message;
                response.code = "CONFLICT";
                response.details = ex.Message;
                break;

            case ConflictException ex:
                response.statusCode = (int)HttpStatusCode.Conflict;
                response.message = ex.Message;
                response.code = "SCHEDULE_CONFLICT";
                response.details = ex.Message;
                break;

            case BusinessRuleException ex:
                response.statusCode = (int)HttpStatusCode.UnprocessableEntity;
                response.message = ex.Message;
                response.code = "BUSINESS_RULE_VIOLATION";
                response.details = ex.Message;
                break;

            case UnauthorizedAccessException ex:
                response.statusCode = (int)HttpStatusCode.Unauthorized;
                response.message = ex.Message;
                response.code = "UNAUTHORIZED";
                response.details = ex.Message;
                break;

            case BadHttpRequestException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = "The request could not be processed.";
                response.code = "BAD_REQUEST";
                response.details = ex.Message;
                break;

            case JsonException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = "The request body contains invalid JSON.";
                response.code = "INVALID_JSON";
                response.details = ex.Message;
                break;

            case ArgumentException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = "One or more request arguments are invalid.";
                response.code = "INVALID_ARGUMENT";
                response.details = ex.Message;
                break;

            case HttpRequestException ex:
                response.statusCode = (int)HttpStatusCode.BadGateway;
                response.message = "A downstream service request failed.";
                response.code = "UPSTREAM_REQUEST_FAILED";
                response.details = ex.Message;
                break;

            case TaskCanceledException ex:
                response.statusCode = (int)HttpStatusCode.GatewayTimeout;
                response.message = "A downstream service request timed out.";
                response.code = "UPSTREAM_TIMEOUT";
                response.details = ex.Message;
                break;

            case DbUpdateException ex:
                return MapDatabaseException(ex, traceId, includeDebugDetails);

            case PostgresException ex:
                return MapPostgresException(ex, traceId, includeDebugDetails);

            case InvalidOperationException ex:
                response.statusCode = (int)HttpStatusCode.InternalServerError;
                response.message = "The server encountered an invalid application state.";
                response.code = "INVALID_OPERATION";
                response.details = ex.Message;
                break;

            default:
                response.details = includeDebugDetails ? GetMostRelevantMessage(exception) : $"See traceId '{traceId}' in server logs.";
                if (includeDebugDetails) response.stackTrace = exception.StackTrace;
                break;
        }

        if (includeDebugDetails && response.stackTrace is null && IsKnownError(response.code))
        {
            response.stackTrace = exception.StackTrace;
        }

        return response;
    }

    private static ErrorResponse MapDatabaseException(DbUpdateException exception, string traceId, bool includeDebugDetails)
    {
        if (exception.InnerException is PostgresException postgresException)
        {
            return MapPostgresException(postgresException, traceId, includeDebugDetails);
        }

        return new ErrorResponse
        {
            statusCode = (int)HttpStatusCode.InternalServerError,
            message = "A database operation failed.",
            code = "DATABASE_ERROR",
            details = includeDebugDetails ? GetMostRelevantMessage(exception) : $"See traceId '{traceId}' in server logs.",
            stackTrace = includeDebugDetails ? exception.StackTrace : null,
            traceId = traceId,
        };
    }

    private static ErrorResponse MapPostgresException(PostgresException exception, string traceId, bool includeDebugDetails)
    {
        var response = new ErrorResponse
        {
            statusCode = (int)HttpStatusCode.InternalServerError,
            message = "A database error occurred.",
            code = "DATABASE_ERROR",
            details = includeDebugDetails ? exception.MessageText : $"See traceId '{traceId}' in server logs.",
            stackTrace = includeDebugDetails ? exception.StackTrace : null,
            traceId = traceId,
        };

        switch (exception.SqlState)
        {
            case PostgresErrorCodes.UniqueViolation:
                response.statusCode = (int)HttpStatusCode.Conflict;
                response.message = "A record with the same unique value already exists.";
                response.code = "UNIQUE_VIOLATION";
                response.details = BuildDatabaseDetail(exception, "unique constraint");
                break;

            case PostgresErrorCodes.ForeignKeyViolation:
                response.statusCode = (int)HttpStatusCode.Conflict;
                response.message = "The requested change violates a related record constraint.";
                response.code = "FOREIGN_KEY_VIOLATION";
                response.details = BuildDatabaseDetail(exception, "foreign key");
                break;

            // A value longer than its column: the request's fault, not a server error
            case PostgresErrorCodes.StringDataRightTruncation:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = "A value is too long.";
                response.code = "VALUE_TOO_LONG";
                response.details = BuildDatabaseDetail(exception, "value too long");
                break;

            case PostgresErrorCodes.NotNullViolation:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = "A required database field was missing.";
                response.code = "NOT_NULL_VIOLATION";
                response.details = BuildDatabaseDetail(exception, "required field");
                break;

            case PostgresErrorCodes.UndefinedTable:
                response.statusCode = (int)HttpStatusCode.InternalServerError;
                response.message = "A required database table is missing.";
                response.code = "DATABASE_SCHEMA_MISSING";
                response.details = BuildDatabaseDetail(exception, "missing table");
                break;

            case PostgresErrorCodes.UndefinedColumn:
                response.statusCode = (int)HttpStatusCode.InternalServerError;
                response.message = "A required database column is missing.";
                response.code = "DATABASE_SCHEMA_MISMATCH";
                response.details = BuildDatabaseDetail(exception, "missing column");
                break;
        }

        return response;
    }

    private static string BuildDatabaseDetail(PostgresException exception, string fallbackLabel)
    {
        if (!string.IsNullOrWhiteSpace(exception.TableName))
        {
            if (!string.IsNullOrWhiteSpace(exception.ColumnName))
            {
                return $"Database issue on table '{exception.TableName}', column '{exception.ColumnName}'.";
            }

            return $"Database issue on table '{exception.TableName}'.";
        }

        if (!string.IsNullOrWhiteSpace(exception.ConstraintName))
        {
            return $"Database constraint issue: '{exception.ConstraintName}'.";
        }

        return exception.MessageText ?? $"Database {fallbackLabel} error.";
    }

    private static bool IsKnownError(string code)
        => code is not "INTERNAL_ERROR";

    private static string GetMostRelevantMessage(Exception exception)
    {
        var current = exception;
        while (current.InnerException is not null)
        {
            current = current.InnerException;
        }

        return current.Message;
    }
}

public class ErrorResponse
{
    public string message { get; set; } = string.Empty;
    public string code { get; set; } = string.Empty;
    public string? details { get; set; }
    public string? stackTrace { get; set; }
    public string? traceId { get; set; }
    public int statusCode { get; set; }
    public string? path { get; set; }
}
