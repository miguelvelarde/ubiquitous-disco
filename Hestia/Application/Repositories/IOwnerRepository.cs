using Hestia.Domain.PropertyManagement;

namespace Hestia.Application.Repositories;

public interface IOwnerRepository
{
    Task AddAsync(Owner owner, CancellationToken ct = default);
    Task<Owner?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyCollection<Owner>> ListAsync(CancellationToken ct = default);
    Task UpdateAsync(Owner owner, CancellationToken ct = default);
}
