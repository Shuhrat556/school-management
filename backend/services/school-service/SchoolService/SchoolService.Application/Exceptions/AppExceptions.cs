namespace SchoolService.Application.Exceptions;

// Thrown when a requested resource doesn't exist - maps to 404
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }

    public NotFoundException(string resource, Guid id)
        : base($"{resource} with ID '{id}' was not found.") { }
}

// Thrown when input fails validation - maps to 400
public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}

// Thrown when a conflicting resource already exists - maps to 409
public class DuplicateException : Exception
{
    public DuplicateException(string message) : base(message) { }
}

// Thrown when a business rule is violated - maps to 422
public class BusinessRuleException : Exception
{
    public BusinessRuleException(string message) : base(message) { }
}

// Thrown when a scheduling conflict is detected - maps to 409
public class ConflictException : Exception
{
    public ConflictException(string message) : base(message) { }
}

// Thrown when the caller may not do this to this resource - maps to 403
public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}

// Thrown when the caller is doing something too often - maps to 429
public class TooManyRequestsException : Exception
{
    public TooManyRequestsException(string message) : base(message) { }
}
