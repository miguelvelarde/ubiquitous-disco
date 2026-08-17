namespace Hestia.Domain.Billing;

/// <summary>
/// Represents the lifecycle state of a charge.
/// </summary>
public enum ChargeStatus
{
    Pending,
    Paid,
    Waived,
    Cancelled
}
