using Hestia.Application.Repositories;
using Hestia.Domain.Billing;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Hestia.Application.Services;

public sealed class ChargeService
{
    private readonly IChargeRepository _charges;

    public ChargeService(IChargeRepository charges) => _charges = charges;

    public Task CreateChargeAsync(Charge charge, CancellationToken ct = default)
        => _charges.AddAsync(charge, ct);

    public async Task RegisterPaymentAsync(
        Guid chargeId,
        DateTimeOffset paymentDate,
        decimal amount,
        PaymentMethod paymentMethod,
        string reference,
        string notes,
        DateTimeOffset createdAt,
        Guid createdBy,
        CancellationToken ct = default)
    {
        var charge = await _charges.GetByIdAsync(chargeId, ct) ?? throw new InvalidOperationException("Charge not found");
        charge.Pay(paymentDate, amount, paymentMethod, reference, notes, createdAt, createdBy);
        await _charges.UpdateAsync(charge, ct);
    }
}
