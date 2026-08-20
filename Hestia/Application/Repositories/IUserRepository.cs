using Hestia.Domain.Security;

namespace Hestia.Application.Repositories;

public interface IUserRepository
{
    Task AddAsync(User user, CancellationToken ct = default);
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default);
    Task<IReadOnlyCollection<User>> ListAsync(CancellationToken ct = default);
    Task UpdateAsync(User user, CancellationToken ct = default);
}
