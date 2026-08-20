using Dapper;
using Hestia.Application.Repositories;
using Hestia.Domain.PropertyManagement;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Data;

namespace Hestia.Infrastructure.Postgres;

public sealed class DepartmentRepository : IDepartmentRepository
{
    private readonly string _connectionString;

    public DepartmentRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? configuration["ConnectionStrings:Default"]
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
    }

    private IDbConnection CreateConnection() => new NpgsqlConnection(_connectionString);

    public async Task AddAsync(Department department, CancellationToken ct = default)
    {
        const string sql = @"INSERT INTO cas.departments (id, owner_id, building, number, status, created_at)
            VALUES (@Id, @OwnerId, @Building, @Number, @Status, @CreatedAt)";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            department.Id,
            department.OwnerId,
            department.Building,
            department.Number,
            Status = department.Status.ToString(),
            department.CreatedAt
        }, cancellationToken: ct));
    }

    public async Task<Department?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, owner_id, building, number, status, created_at
            FROM cas.departments
            WHERE id = @Id";

        using var db = CreateConnection();
        var row = await db.QuerySingleOrDefaultAsync<dynamic>(
            new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));

        return row is null
            ? null
            : new Department(
                (Guid)row.id,
                (Guid)row.owner_id,
                (string)row.building,
                (string)row.number,
                Enum.Parse<DepartmentStatus>((string)row.status),
                (DateTimeOffset)row.created_at);
    }

    public async Task<IReadOnlyCollection<Department>> ListAsync(CancellationToken ct = default)
    {
        const string sql = @"SELECT id, owner_id, building, number, status, created_at
            FROM cas.departments
            ORDER BY building, number, id";

        using var db = CreateConnection();
        var rows = await db.QueryAsync<dynamic>(new CommandDefinition(sql, cancellationToken: ct));
        return rows
            .Select(static row => new Department(
                (Guid)row.id,
                (Guid)row.owner_id,
                (string)row.building,
                (string)row.number,
                Enum.Parse<DepartmentStatus>((string)row.status),
                (DateTimeOffset)row.created_at))
            .ToArray();
    }

    public async Task UpdateAsync(Department department, CancellationToken ct = default)
    {
        const string sql = @"UPDATE cas.departments
            SET owner_id = @OwnerId,
                status = @Status
            WHERE id = @Id";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            department.Id,
            department.OwnerId,
            Status = department.Status.ToString()
        }, cancellationToken: ct));
    }
}
