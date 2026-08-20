using Hestia.Domain.Security;

namespace Hestia.Application.DTOs.Security;

public sealed record UserDto(
    Guid Id,
    string Username,
    UserRole Role,
    DateTimeOffset CreatedAt)
{
    public static UserDto FromDomain(User user) =>
        new(user.Id, user.Username, user.Role, user.CreatedAt);
}
