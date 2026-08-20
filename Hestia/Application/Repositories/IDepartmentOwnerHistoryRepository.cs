using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.Repositories;

public interface IDepartmentOwnerHistoryRepository
{
    Task AddAsync(DepartmentOwnerHistory history, CancellationToken ct = default);
    Task<DepartmentOwnerHistory?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyCollection<DepartmentOwnerHistory>> ListByDepartmentAsync(Guid departmentId, CancellationToken ct = default);
    Task UpdateAsync(DepartmentOwnerHistory history, CancellationToken ct = default);
}
