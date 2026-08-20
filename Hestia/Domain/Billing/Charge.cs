namespace Hestia.Domain.Billing;

/// <summary>
/// Aggregate root that protects the lifecycle and settlement of a charge.
/// </summary>
public sealed class Charge
{
    public Charge(
        Guid id,
        Guid departmentId,
        Guid serviceCatalogId,
        decimal amount,
        int? billingPeriod,
        DateOnly dueDate,
        ChargeOrigin origin,
        DateTimeOffset createdAt,
        Guid createdBy)
        : this(
            id,
            departmentId,
            serviceCatalogId,
            amount,
            amount,
            billingPeriod,
            dueDate,
            origin,
            amount == 0 ? ChargeStatus.Waived : ChargeStatus.Pending,
            createdAt,
            createdBy)
    {
    }

    internal static Charge Rehydrate(
        Guid id,
        Guid departmentId,
        Guid serviceCatalogId,
        decimal originalAmount,
        decimal amount,
        int? billingPeriod,
        DateOnly dueDate,
        ChargeOrigin origin,
        ChargeStatus status,
        DateTimeOffset createdAt,
        Guid createdBy)
        => new Charge(id, departmentId, serviceCatalogId, originalAmount, amount, billingPeriod, dueDate, origin, status, createdAt, createdBy);

    internal void AttachPayment(Payment payment)
    {
        Payment = payment;
        Status = ChargeStatus.Paid;
    }

    internal Charge(
        Guid id,
        Guid departmentId,
        Guid serviceCatalogId,
        decimal originalAmount,
        decimal amount,
        int? billingPeriod,
        DateOnly dueDate,
        ChargeOrigin origin,
        ChargeStatus status,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A charge requires an identifier.", nameof(id));
        }

        if (departmentId == Guid.Empty)
        {
            throw new ArgumentException("A charge requires a department identifier.", nameof(departmentId));
        }

        if (serviceCatalogId == Guid.Empty)
        {
            throw new ArgumentException("A charge requires a service catalog identifier.", nameof(serviceCatalogId));
        }

        if (billingPeriod.HasValue)
        {
            BillingPeriodValidator.EnsureValid(billingPeriod.Value, nameof(billingPeriod));
        }

        ArgumentNullException.ThrowIfNull(origin);

        if (createdBy == Guid.Empty)
        {
            throw new ArgumentException("A charge requires its creator identifier.", nameof(createdBy));
        }

        if (origin.Type == ChargeOriginType.Adjustment)
        {
            if (originalAmount != 0)
            {
                throw new ArgumentException("An adjustment charge must have an original amount of zero.", nameof(originalAmount));
            }

            if (amount == 0)
            {
                throw new ArgumentOutOfRangeException(nameof(amount), amount, "An adjustment charge amount cannot be zero.");
            }

            if (status != ChargeStatus.Paid)
            {
                throw new ArgumentException("An adjustment charge must be created as paid.", nameof(status));
            }
        }
        else if (originalAmount < 0 || amount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), amount, "Normal charge amounts cannot be negative.");
        }

        Id = id;
        DepartmentId = departmentId;
        ServiceCatalogId = serviceCatalogId;
        OriginalAmount = originalAmount;
        Amount = amount;
        BillingPeriod = billingPeriod;
        DueDate = dueDate;
        Origin = origin;
        Status = status;
        CreatedAt = createdAt;
        CreatedBy = createdBy;
    }

    public Guid Id { get; }

    public Guid DepartmentId { get; }

    public Guid ServiceCatalogId { get; }

    public decimal OriginalAmount { get; }

    public decimal Amount { get; private set; }

    public int? BillingPeriod { get; }

    public DateOnly DueDate { get; }

    public ChargeOrigin Origin { get; }

    public ChargeStatus Status { get; private set; }

    public Payment? Payment { get; private set; }

    public DateTimeOffset CreatedAt { get; }

    public Guid CreatedBy { get; }

    public static Charge CreateAdjustment(
        Guid id,
        Guid departmentId,
        Guid serviceCatalogId,
        decimal amount,
        DateOnly dueDate,
        DateTimeOffset createdAt,
        Guid createdBy) =>
        new(
            id,
            departmentId,
            serviceCatalogId,
            originalAmount: 0,
            amount: amount,
            billingPeriod: null,
            dueDate: dueDate,
            origin: ChargeOrigin.Adjustment(),
            status: ChargeStatus.Paid,
            createdAt: createdAt,
            createdBy: createdBy);

    public Payment Pay(
        DateTimeOffset paymentDate,
        decimal amount,
        PaymentMethod paymentMethod,
        string reference,
        string notes,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (Status != ChargeStatus.Pending)
        {
            throw new InvalidOperationException("Only pending charges can be paid.");
        }

        if (Payment is not null)
        {
            throw new InvalidOperationException("A charge cannot contain more than one payment.");
        }

        if (amount != Amount)
        {
            throw new ArgumentException("Payment amount must equal the current charge amount.", nameof(amount));
        }

        var payment = new Payment(
            Guid.NewGuid(),
            Id,
            paymentDate,
            amount,
            paymentMethod,
            reference,
            notes,
            createdAt,
            createdBy);

        Payment = payment;
        Status = ChargeStatus.Paid;

        return payment;
    }

    public void Waive()
    {
        if (Status != ChargeStatus.Pending)
        {
            throw new InvalidOperationException("Only pending charges can be waived.");
        }

        Amount = 0;
        Status = ChargeStatus.Waived;
    }

    public void Cancel()
    {
        if (Status != ChargeStatus.Pending)
        {
            throw new InvalidOperationException("Only pending charges can be cancelled.");
        }

        Status = ChargeStatus.Cancelled;
    }
}
