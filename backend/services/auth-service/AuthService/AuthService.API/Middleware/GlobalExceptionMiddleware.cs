using System.Diagnostics;
using System.Net;
using System.Text.Json;
using AuthService.Application.Exceptions;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AuthService.API.Middleware;

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
            _logger.LogError(
                exception,
                "Unhandled exception for {Method} {Path}. TraceId: {TraceId}",
                context.Request.Method,
                context.Request.Path,
                traceId);

            await HandleExceptionAsync(context, exception, traceId, _environment.IsDevelopment());
        }
    }

    private static Task HandleExceptionAsync(HttpContext context, Exception exception, string traceId, bool includeDebugDetails)
    {
        context.Response.ContentType = "application/json";

        var response = MapException(exception, traceId, includeDebugDetails);
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
        };

        switch (exception)
        {
            case ValidationException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = ex.Message;
                response.code = "VALIDATION_ERROR";
                response.details = ex.Message;
                break;

            case NotFoundException ex:
                response.statusCode = (int)HttpStatusCode.NotFound;
                response.message = ex.Message;
                response.code = "NOT_FOUND";
                response.details = ex.Message;
                break;

            case DuplicateEmailException ex:
                response.statusCode = (int)HttpStatusCode.Conflict;
                response.message = ex.Message;
                response.code = "EMAIL_ALREADY_EXISTS";
                response.details = ex.Message;
                break;

            case ConfigurationException ex:
                response.statusCode = (int)HttpStatusCode.InternalServerError;
                response.message = ex.Message;
                response.code = "CONFIGURATION_ERROR";
                response.details = ex.Message;
                break;

            case AuthService.Application.Exceptions.InvalidOperationException ex:
                response.statusCode = (int)HttpStatusCode.BadRequest;
                response.message = ex.Message;
                response.code = "INVALID_OPERATION";
                response.details = ex.Message;
                break;

            case ExternalTokenException ex:
                response.statusCode = (int)HttpStatusCode.Unauthorized;
                response.message = ex.Message;
                response.code = "INVALID_EXTERNAL_TOKEN";
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

            default:
                response.details = includeDebugDetails ? GetMostRelevantMessage(exception) : $"See traceId '{traceId}' in server logs.";
                if (includeDebugDetails) response.stackTrace = exception.StackTrace;
                break;
        }

        if (includeDebugDetails && response.stackTrace is null && response.code is not "INTERNAL_ERROR")
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
