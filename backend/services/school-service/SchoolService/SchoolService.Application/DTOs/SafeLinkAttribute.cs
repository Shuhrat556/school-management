using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace SchoolService.Application.DTOs;

// A link shown to other users: an http(s) URL or a plain reference such as a file name.
// Any other scheme (javascript:, data:, vbscript:, file: ...) is refused, so a stored
// value can never run script when someone opens it.
[AttributeUsage(AttributeTargets.Property)]
public sealed partial class SafeLinkAttribute : ValidationAttribute
{
    [GeneratedRegex(@"^\s*([a-zA-Z][a-zA-Z0-9+.\-]*):")]
    private static partial Regex Scheme();

    public SafeLinkAttribute() : base("{0} must be an http(s) link or a plain file reference.") { }

    public override bool IsValid(object? value)
    {
        if (value is not string link || string.IsNullOrWhiteSpace(link)) return true;
        var match = Scheme().Match(link);
        if (!match.Success) return true;
        var scheme = match.Groups[1].Value;
        return scheme.Equals("http", StringComparison.OrdinalIgnoreCase)
            || scheme.Equals("https", StringComparison.OrdinalIgnoreCase);
    }
}
