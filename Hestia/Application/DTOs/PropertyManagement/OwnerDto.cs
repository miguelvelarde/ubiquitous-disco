using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.DTOs.PropertyManagement;

public sealed record OwnerDto(
    Guid Id,
    string Name,
    string? Email,
    string? Phone,
    DateTimeOffset CreatedAt)
{
    public static OwnerDto FromDomain(Owner owner) =>
        new(owner.Id, owner.Name, owner.Email, owner.Phone, owner.CreatedAt);
}
