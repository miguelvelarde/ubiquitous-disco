using Dapper;
using Hestia.Application.Repositories;
using Hestia.Domain.Billing;
using Microsoft.Extensions.Configuration;
using Npgsql;
using System.Data;

namespace Hestia.Infrastructure.Postgres;

public sealed class ChargeRepository : IChargeRepository
{
    private readonly string _connectionString;

    public ChargeRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? configuration["ConnectionStrings:Default"]
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
    }

    private IDbConnection CreateConnection() => new NpgsqlConnection(_connectionString);

    public async Task AddAsync(Charge charge, CancellationToken ct = default)
    {
        const string sql = @"INSERT INTO charges (
            id, department_id, service_catalog_id, reservation_id, source_type, billing_period,
            original_amount, amount, due_date, status, created_at, created_by)
            VALUES (@Id, @DepartmentId, @ServiceCatalogId, @ReservationId, @SourceType, @BillingPeriod,
            @OriginalAmount, @Amount, @DueDate, @Status, @CreatedAt, @CreatedBy)";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new
        {
            Id = charge.Id,
            DepartmentId = charge.DepartmentId,
            ServiceCatalogId = charge.ServiceCatalogId,
            ReservationId = charge.Origin.Type == ChargeOriginType.Reservation ? charge.Origin.ReservationId : null,
            SourceType = charge.Origin.Type.ToString(),
            BillingPeriod = charge.BillingPeriod,
            OriginalAmount = charge.OriginalAmount,
            Amount = charge.Amount,
            DueDate = charge.DueDate.ToDateTime(TimeOnly.MinValue),
            Status = charge.Status.ToString(),
            CreatedAt = charge.CreatedAt,
            CreatedBy = charge.CreatedBy
        }, cancellationToken: ct));
    }

    public async Task<Charge?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        const string sql = @"SELECT c.*, p.id as payment_id, p.payment_date, p.amount as payment_amount,
            p.payment_method, p.reference, p.notes, p.created_at as payment_created_at, p.created_by as payment_created_by
            FROM charges c
            LEFT JOIN payments p ON p.charge_id = c.id
            WHERE c.id = @Id";

        using var db = CreateConnection();
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));
        if (row is null) return null;

        ChargeOrigin origin = row.source_type switch
        {
            "Reservation" => ChargeOrigin.ForReservation(row.reservation_id is null ? Guid.Empty : (Guid)row.reservation_id),
            "Adjustment" => ChargeOrigin.Adjustment(),
            "Recurring" => ChargeOrigin.ForRecurring(),
            _ => ChargeOrigin.Extraordinary()
        };

        var createdAt = (DateTimeOffset)row.created_at;
        var dueDate = DateOnly.FromDateTime((DateTime)row.due_date);

        var charge = Charge.Rehydrate(
            (Guid)row.id,
            (Guid)row.department_id,
            (Guid)row.service_catalog_id,
            (decimal)row.original_amount,
            (decimal)row.amount,
            row.billing_period is null ? null : (int?)row.billing_period,
            dueDate,
            origin,
            Enum.Parse<ChargeStatus>((string)row.status),
            createdAt,
            (Guid)row.created_by);

        if (row.payment_id is not null)
        {
            var payment = new Payment(
                (Guid)row.payment_id,
                (Guid)row.id,
                (DateTimeOffset)row.payment_date,
                (decimal)row.payment_amount,
                Enum.Parse<PaymentMethod>((string)row.payment_method),
                (string)row.reference,
                (string)row.notes,
                (DateTimeOffset)row.payment_created_at,
                (Guid)row.payment_created_by);

            charge.AttachPayment(payment);
        }

        return charge;
    }

    public async Task UpdateAsync(Charge charge, CancellationToken ct = default)
    {
        const string sql = @"UPDATE charges SET amount = @Amount, status = @Status WHERE id = @Id";

        using var db = CreateConnection();
        await db.ExecuteAsync(new CommandDefinition(sql, new { Amount = charge.Amount, Status = charge.Status.ToString(), Id = charge.Id }, cancellationToken: ct));

        if (charge.Payment is not null)
        {
            const string ins = @"INSERT INTO payments (id, charge_id, payment_date, amount, payment_method, reference, notes, created_at, created_by)
                VALUES (@Id, @ChargeId, @PaymentDate, @Amount, @PaymentMethod, @Reference, @Notes, @CreatedAt, @CreatedBy)
                ON CONFLICT (charge_id) DO NOTHING";

            await db.ExecuteAsync(new CommandDefinition(ins, new
            {
                Id = charge.Payment.Id,
                ChargeId = charge.Payment.ChargeId,
                PaymentDate = charge.Payment.PaymentDate,
                Amount = charge.Payment.Amount,
                PaymentMethod = charge.Payment.PaymentMethod.ToString(),
                Reference = charge.Payment.Reference,
                Notes = charge.Payment.Notes,
                CreatedAt = charge.Payment.CreatedAt,
                CreatedBy = charge.Payment.CreatedBy
            }, cancellationToken: ct));
        }
    }
}
