namespace AuthService.Application.Exceptions;

// Thrown when input data fails validation
public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}

// Thrown when a requested resource doesn't exist
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}

// Thrown when someone tries to register with an email that's already taken
public class DuplicateEmailException : Exception
{
    public DuplicateEmailException(string email) 
        : base($"Email '{email}' is already registered") { }
}

// Thrown when the app config is missing or invalid
public class ConfigurationException : Exception
{
    public ConfigurationException(string message) : base(message) { }
}

// Thrown when an account is temporarily locked after repeated wrong passwords
public class AccountLockedException : Exception
{
    public DateTime LockedUntil { get; }

    public AccountLockedException(DateTime lockedUntil)
        : base("Too many failed sign-in attempts. Try again later.")
        => LockedUntil = lockedUntil;
}

// Thrown after a correct password when the account's email is not verified yet
public class EmailNotVerifiedException : Exception
{
    public EmailNotVerifiedException() : base("Please verify your email before logging in") { }
}

// Thrown when an operation isn't allowed in the current state
public class InvalidOperationException : Exception
{
    public InvalidOperationException(string message) : base(message) { }
}

// Thrown when a Google/Facebook sign-in token is malformed, expired or issued for another app
public class ExternalTokenException : Exception
{
    public ExternalTokenException(string message) : base(message) { }
}
