using Xunit;
using Hestia.Domain.Billing;

namespace Hestia.Tests.Domain.Billing;

public sealed class ChargeOriginTests
{
    [Fact]
    public void ForRecurringService_SetsOnlyRecurringServiceReference()
    {
        var recurringServiceId = Guid.NewGuid();

        var origin = ChargeOrigin.ForRecurringService(recurringServiceId);

        Assert.Equal(ChargeOriginType.RecurringService, origin.Type);
        Assert.Equal(recurringServiceId, origin.RecurringServiceId);
        Assert.Null(origin.ReservationId);
    }

    [Fact]
    public void ForReservation_SetsOnlyReservationReference()
    {
        var reservationId = Guid.NewGuid();

        var origin = ChargeOrigin.ForReservation(reservationId);

        Assert.Equal(ChargeOriginType.Reservation, origin.Type);
        Assert.Null(origin.RecurringServiceId);
        Assert.Equal(reservationId, origin.ReservationId);
    }

    [Fact]
    public void Extraordinary_HasNoOriginReference()
    {
        var origin = ChargeOrigin.Extraordinary();

        Assert.Equal(ChargeOriginType.Extraordinary, origin.Type);
        Assert.Null(origin.RecurringServiceId);
        Assert.Null(origin.ReservationId);
    }

    [Fact]
    public void Adjustment_HasNoOriginReference()
    {
        var origin = ChargeOrigin.Adjustment();

        Assert.Equal(ChargeOriginType.Adjustment, origin.Type);
        Assert.Null(origin.RecurringServiceId);
        Assert.Null(origin.ReservationId);
    }

    [Fact]
    public void EqualOrigins_HaveValueEquality()
    {
        var recurringServiceId = Guid.NewGuid();
        var first = ChargeOrigin.ForRecurringService(recurringServiceId);
        var second = ChargeOrigin.ForRecurringService(recurringServiceId);

        Assert.Equal(first, second);
        Assert.Equal(first.GetHashCode(), second.GetHashCode());
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void SourceOrigin_WithEmptyReference_ThrowsArgumentException(bool recurringService)
    {
        Action action = recurringService
            ? () => ChargeOrigin.ForRecurringService(Guid.Empty)
            : () => ChargeOrigin.ForReservation(Guid.Empty);

        Assert.Throws<ArgumentException>(action);
    }
}
