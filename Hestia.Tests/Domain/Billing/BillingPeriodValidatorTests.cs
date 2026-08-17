using Xunit;
using Hestia.Domain.Billing;

namespace Hestia.Tests.Domain.Billing;

public sealed class BillingPeriodValidatorTests
{
    [Theory]
    [InlineData(190001)]
    [InlineData(202608)]
    [InlineData(999912)]
    public void IsValid_WhenValueUsesSupportedYearAndMonth_ReturnsTrue(int billingPeriod)
    {
        Assert.True(BillingPeriodValidator.IsValid(billingPeriod));
    }

    [Theory]
    [InlineData(189912)]
    [InlineData(190000)]
    [InlineData(202613)]
    [InlineData(999913)]
    public void IsValid_WhenValueDoesNotUseValidYearAndMonth_ReturnsFalse(int billingPeriod)
    {
        Assert.False(BillingPeriodValidator.IsValid(billingPeriod));
    }

    [Fact]
    public void EnsureValid_WhenValueIsInvalid_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => BillingPeriodValidator.EnsureValid(202600));
    }
}
