namespace Hestia.Domain.Billing;

/// <summary>
/// Validates the integer YYYYMM representation used for charge billing periods.
/// </summary>
public static class BillingPeriodValidator
{
    private const int MinimumYear = 1900;
    private const int MaximumYear = 9999;

    public static bool IsValid(int billingPeriod)
    {
        var year = billingPeriod / 100;
        var month = billingPeriod % 100;

        return year is >= MinimumYear and <= MaximumYear
            && month is >= 1 and <= 12;
    }

    public static void EnsureValid(int billingPeriod, string? parameterName = null)
    {
        if (!IsValid(billingPeriod))
        {
            throw new ArgumentOutOfRangeException(
                parameterName ?? nameof(billingPeriod),
                billingPeriod,
                "Billing period must be a valid YYYYMM value.");
        }
    }
}
