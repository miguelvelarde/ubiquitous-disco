namespace Hestia.Domain.Billing;

/// <summary>
/// Immutable source information for a charge.
/// </summary>
public sealed class ChargeOrigin : IEquatable<ChargeOrigin>
{
    private ChargeOrigin(
        ChargeOriginType type,
        Guid? recurringServiceId,
        Guid? reservationId)
    {
        Type = type;
        RecurringServiceId = recurringServiceId;
        ReservationId = reservationId;
    }

    public ChargeOriginType Type { get; }

    public Guid? RecurringServiceId { get; }

    public Guid? ReservationId { get; }

    public static ChargeOrigin ForRecurringService(Guid recurringServiceId)
    {
        if (recurringServiceId == Guid.Empty)
        {
            throw new ArgumentException("A recurring-service origin requires an identifier.", nameof(recurringServiceId));
        }

        return new ChargeOrigin(ChargeOriginType.RecurringService, recurringServiceId, null);
    }

    public static ChargeOrigin ForRecurring()
        => new ChargeOrigin(ChargeOriginType.RecurringService, null, null);

    public static ChargeOrigin ForReservation(Guid reservationId)
    {
        if (reservationId == Guid.Empty)
        {
            throw new ArgumentException("A reservation origin requires an identifier.", nameof(reservationId));
        }

        return new ChargeOrigin(ChargeOriginType.Reservation, null, reservationId);
    }

    public static ChargeOrigin Extraordinary() =>
        new(ChargeOriginType.Extraordinary, null, null);

    public static ChargeOrigin Adjustment() =>
        new(ChargeOriginType.Adjustment, null, null);

    public bool Equals(ChargeOrigin? other) =>
        other is not null
        && Type == other.Type
        && RecurringServiceId == other.RecurringServiceId
        && ReservationId == other.ReservationId;

    public override bool Equals(object? obj) => Equals(obj as ChargeOrigin);

    public override int GetHashCode() =>
        HashCode.Combine(Type, RecurringServiceId, ReservationId);
}
