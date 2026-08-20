using Dapper;
using Hestia.Application.Repositories;
using Hestia.Domain.PropertyManagement;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Data;

namespace Hestia.Infrastructure.Postgres;

public sealed class OwnerRepository : IOwnerRepository
{
    private readonly string _connectionString;

    public OwnerRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? configuration["ConnectionStrings:Default"]
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
    }

    private IDbConnection CreateConnection() => new NpgsqlConnection(_connectionString);

    public async Task AddAsync(Owner owner, CancellationToken ct = default)
    {
        const string sql = @"INSERT INTO cas.owners (id, name, email, phone, created_at)
            VALUES (@Id, @Name, @Email, @Phone, @CreatedAt)";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, owner, cancellationToken: ct));
    }

    public async Task<Owner?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, name, email, phone, created_at
            FROM cas.owners
            WHERE id = @Id";

        using var db = CreateConnection();
        return await db.QuerySingleOrDefaultAsync<Owner>(
            new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));
    }

    public async Task<IReadOnlyCollection<Owner>> ListAsync(CancellationToken ct = default)
    {
        const string sql = @"SELECT id, name, email, phone, created_at
            FROM cas.owners
            ORDER BY name, id";

        using var db = CreateConnection();
        var owners = await db.QueryAsync<Owner>(new CommandDefinition(sql, cancellationToken: ct));
        return owners.AsList();
    }

    public async Task UpdateAsync(Owner owner, CancellationToken ct = default)
    {
        const string sql = @"UPDATE cas.owners
            SET name = @Name,
                email = @Email,
                phone = @Phone
            WHERE id = @Id";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, owner, cancellationToken: ct));
    }
}
