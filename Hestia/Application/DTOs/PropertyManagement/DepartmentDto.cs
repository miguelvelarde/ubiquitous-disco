using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.DTOs.PropertyManagement;

public sealed record DepartmentDto(
    Guid Id,
    Guid OwnerId,
    string Building,
    string Number,
    DepartmentStatus Status,
    DateTimeOffset CreatedAt)
{
    public static DepartmentDto FromDomain(Department department) =>
        new(
            department.Id,
            department.OwnerId,
            department.Building,
            department.Number,
            department.Status,
            department.CreatedAt);
}
