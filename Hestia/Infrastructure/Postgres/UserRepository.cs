using Dapper;
using Hestia.Application.Repositories;
using Hestia.Domain.Security;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Data;

namespace Hestia.Infrastructure.Postgres;

public sealed class UserRepository : IUserRepository
{
    private readonly string _connectionString;

    public UserRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? configuration["ConnectionStrings:Default"]
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
    }

    private IDbConnection CreateConnection() => new NpgsqlConnection(_connectionString);

    public async Task AddAsync(User user, CancellationToken ct = default)
    {
        const string sql = @"INSERT INTO cas.users (id, username, password_hash, role, created_at)
            VALUES (@Id, @Username, @PasswordHash, @Role, @CreatedAt)";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            user.Id,
            user.Username,
            user.PasswordHash,
            Role = user.Role.ToString(),
            user.CreatedAt
        }, cancellationToken: ct));
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, username, password_hash, role, created_at
            FROM cas.users
            WHERE id = @Id";

        using var db = CreateConnection();
        var row = await db.QuerySingleOrDefaultAsync<dynamic>(
            new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));

        return row is null
            ? null
            : new User(
                (Guid)row.id,
                (string)row.username,
                (string)row.password_hash,
                Enum.Parse<UserRole>((string)row.role),
                (DateTimeOffset)row.created_at);
    }

    public async Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default)
    {
        const string sql = @"SELECT id, username, password_hash, role, created_at
            FROM cas.users
            WHERE username = @Username";

        using var db = CreateConnection();
        var row = await db.QuerySingleOrDefaultAsync<dynamic>(
            new CommandDefinition(sql, new { Username = username }, cancellationToken: ct));

        return row is null
            ? null
            : new User(
                (Guid)row.id,
                (string)row.username,
                (string)row.password_hash,
                Enum.Parse<UserRole>((string)row.role),
                (DateTimeOffset)row.created_at);
    }

    public async Task<IReadOnlyCollection<User>> ListAsync(CancellationToken ct = default)
    {
        const string sql = @"SELECT id, username, password_hash, role, created_at
            FROM cas.users
            ORDER BY username, id";

        using var db = CreateConnection();
        var rows = await db.QueryAsync<dynamic>(new CommandDefinition(sql, cancellationToken: ct));
        return rows
            .Select(static row => new User(
                (Guid)row.id,
                (string)row.username,
                (string)row.password_hash,
                Enum.Parse<UserRole>((string)row.role),
                (DateTimeOffset)row.created_at))
            .ToArray();
    }

    public async Task UpdateAsync(User user, CancellationToken ct = default)
    {
        const string sql = @"UPDATE cas.users
            SET username = @Username,
                password_hash = @PasswordHash,
                role = @Role
            WHERE id = @Id";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            user.Id,
            user.Username,
            user.PasswordHash,
            Role = user.Role.ToString()
        }, cancellationToken: ct));
    }
}
