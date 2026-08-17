namespace Hestia.Domain.Billing;

/// <summary>
/// Identifies the administrator-selected method used to settle a charge.
/// </summary>
public enum PaymentMethod
{
    Cash,
    Card,
    Transfer,
    Other
}
