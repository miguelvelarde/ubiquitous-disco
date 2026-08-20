namespace Hestia.Domain.Billing;

public sealed class Service
{
    public Service(Guid id, string name, string? description, ServiceType type, decimal defaultAmount, bool isReservable, bool isActive, DateTimeOffset createdAt)
    {
        if (id == Guid.Empty) throw new ArgumentException("A service requires an identifier.", nameof(id));
        if (string.IsNullOrWhiteSpace(name)) throw new ArgumentException("A service requires a name.", nameof(name));
        if (type != ServiceType.Adjustment && defaultAmount < 0) throw new ArgumentOutOfRangeException(nameof(defaultAmount));

        Id = id;
        Name = name;
        Description = description;
        Type = type;
        DefaultAmount = defaultAmount;
        IsReservable = isReservable;
        IsActive = isActive;
        CreatedAt = createdAt;
    }

    public Guid Id { get; }
    public string Name { get; }
    public string? Description { get; }
    public ServiceType Type { get; }
    public decimal DefaultAmount { get; }
    public bool IsReservable { get; }
    public bool IsActive { get; }
    public DateTimeOffset CreatedAt { get; }
}