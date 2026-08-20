using Dapper;
using Hestia.Application.Repositories;
using Hestia.Domain.PropertyManagement;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Data;

namespace Hestia.Infrastructure.Postgres;

public sealed class DepartmentOwnerHistoryRepository : IDepartmentOwnerHistoryRepository
{
    private readonly string _connectionString;

    public DepartmentOwnerHistoryRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? configuration["ConnectionStrings:Default"]
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
    }

    private IDbConnection CreateConnection() => new NpgsqlConnection(_connectionString);

    public async Task AddAsync(DepartmentOwnerHistory history, CancellationToken ct = default)
    {
        const string sql = @"INSERT INTO cas.department_owner_history (
            id, department_id, owner_id, start_date, end_date, created_at, created_by)
            VALUES (@Id, @DepartmentId, @OwnerId, @StartDate, @EndDate, @CreatedAt, @CreatedBy)";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            history.Id,
            history.DepartmentId,
            history.OwnerId,
            StartDate = history.StartDate.ToDateTime(TimeOnly.MinValue),
            EndDate = history.EndDate?.ToDateTime(TimeOnly.MinValue),
            history.CreatedAt,
            history.CreatedBy
        }, cancellationToken: ct));
    }

    public async Task<DepartmentOwnerHistory?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, department_id, owner_id, start_date, end_date, created_at, created_by
            FROM cas.department_owner_history
            WHERE id = @Id";

        using var db = CreateConnection();
        var row = await db.QuerySingleOrDefaultAsync<dynamic>(
            new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));

        return row is null
            ? null
            : new DepartmentOwnerHistory(
                (Guid)row.id,
                (Guid)row.department_id,
                (Guid)row.owner_id,
                DateOnly.FromDateTime((DateTime)row.start_date),
                row.end_date is null ? null : DateOnly.FromDateTime((DateTime)row.end_date),
                (DateTimeOffset)row.created_at,
                (Guid)row.created_by);
    }

    public async Task<IReadOnlyCollection<DepartmentOwnerHistory>> ListByDepartmentAsync(Guid departmentId, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, department_id, owner_id, start_date, end_date, created_at, created_by
            FROM cas.department_owner_history
            WHERE department_id = @DepartmentId
            ORDER BY start_date DESC, id";

        using var db = CreateConnection();
        var rows = await db.QueryAsync<dynamic>(
            new CommandDefinition(sql, new { DepartmentId = departmentId }, cancellationToken: ct));

        return rows
            .Select(static row => new DepartmentOwnerHistory(
                (Guid)row.id,
                (Guid)row.department_id,
                (Guid)row.owner_id,
                DateOnly.FromDateTime((DateTime)row.start_date),
                row.end_date is null ? null : DateOnly.FromDateTime((DateTime)row.end_date),
                (DateTimeOffset)row.created_at,
                (Guid)row.created_by))
            .ToArray();
    }

    public async Task UpdateAsync(DepartmentOwnerHistory history, CancellationToken ct = default)
    {
        const string sql = @"UPDATE cas.department_owner_history
            SET end_date = @EndDate
            WHERE id = @Id";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            history.Id,
            EndDate = history.EndDate?.ToDateTime(TimeOnly.MinValue)
        }, cancellationToken: ct));
    }
}
