using Hestia.Domain.Billing;
using System.Threading;
using System.Threading.Tasks;

namespace Hestia.Application.Repositories;

public interface IChargeRepository
{
    Task AddAsync(Charge charge, CancellationToken ct = default);
    Task<Charge?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task UpdateAsync(Charge charge, CancellationToken ct = default);
}
