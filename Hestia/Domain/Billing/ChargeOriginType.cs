namespace Hestia.Domain.Billing;

/// <summary>
/// Identifies the business source that produced a charge.
/// </summary>
public enum ChargeOriginType
{
    RecurringService,
    Reservation,
    Extraordinary
}
