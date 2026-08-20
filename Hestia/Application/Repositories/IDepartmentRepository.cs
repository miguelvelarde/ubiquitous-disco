using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.Repositories;

public interface IDepartmentRepository
{
    Task AddAsync(Department department, CancellationToken ct = default);
    Task<Department?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyCollection<Department>> ListAsync(CancellationToken ct = default);
    Task UpdateAsync(Department department, CancellationToken ct = default);
}
