using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.DTOs.PropertyManagement;

public sealed record DepartmentOwnerHistoryDto(
    Guid Id,
    Guid DepartmentId,
    Guid OwnerId,
    DateOnly StartDate,
    DateOnly? EndDate,
    DateTimeOffset CreatedAt,
    Guid CreatedBy)
{
    public static DepartmentOwnerHistoryDto FromDomain(DepartmentOwnerHistory history) =>
        new(
            history.Id,
            history.DepartmentId,
            history.OwnerId,
            history.StartDate,
            history.EndDate,
            history.CreatedAt,
            history.CreatedBy);
}
