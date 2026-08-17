namespace Hestia.Domain.Billing;

/// <summary>
/// Records the single settlement of a charge. It is owned by the Charge aggregate.
/// </summary>
public sealed class Payment
{
    internal Payment(
        Guid id,
        Guid chargeId,
        DateTimeOffset paymentDate,
        decimal amount,
        PaymentMethod paymentMethod,
        string reference,
        string notes,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A payment requires an identifier.", nameof(id));
        }

        if (chargeId == Guid.Empty)
        {
            throw new ArgumentException("A payment requires a charge identifier.", nameof(chargeId));
        }

        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), amount, "Payment amount must be positive.");
        }

        if (!Enum.IsDefined(paymentMethod))
        {
            throw new ArgumentOutOfRangeException(nameof(paymentMethod), paymentMethod, "Payment method is invalid.");
        }

        if (string.IsNullOrWhiteSpace(reference))
        {
            throw new ArgumentException("A payment reference is required.", nameof(reference));
        }

        if (string.IsNullOrWhiteSpace(notes))
        {
            throw new ArgumentException("Payment notes are required.", nameof(notes));
        }

        if (createdBy == Guid.Empty)
        {
            throw new ArgumentException("A payment requires its creator identifier.", nameof(createdBy));
        }

        Id = id;
        ChargeId = chargeId;
        PaymentDate = paymentDate;
        Amount = amount;
        PaymentMethod = paymentMethod;
        Reference = reference;
        Notes = notes;
        CreatedAt = createdAt;
        CreatedBy = createdBy;
    }

    public Guid Id { get; }

    public Guid ChargeId { get; }

    public DateTimeOffset PaymentDate { get; }

    public decimal Amount { get; }

    public PaymentMethod PaymentMethod { get; }

    public string Reference { get; }

    public string Notes { get; }

    public DateTimeOffset CreatedAt { get; }

    public Guid CreatedBy { get; }
}
