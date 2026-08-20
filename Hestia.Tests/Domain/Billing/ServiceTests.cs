using Hestia.Domain.Billing;
using Xunit;

namespace Hestia.Tests.Domain.Billing;

public sealed class ServiceTests
{
    [Fact]
    public void Constructor_WhenStateIsValid_CreatesService()
    {
        var id = Guid.NewGuid();
        var createdAt = new DateTimeOffset(2026, 8, 20, 9, 0, 0, TimeSpan.Zero);

        var service = new Service(
            id,
            "Club House Rental",
            "Weekend event reservation service.",
            ServiceType.Event,
            1500.00m,
            isReservable: true,
            isActive: true,
            createdAt);

        Assert.Equal(id, service.Id);
        Assert.Equal("Club House Rental", service.Name);
        Assert.Equal("Weekend event reservation service.", service.Description);
        Assert.Equal(ServiceType.Event, service.Type);
        Assert.Equal(1500.00m, service.DefaultAmount);
        Assert.True(service.IsReservable);
        Assert.True(service.IsActive);
        Assert.Equal(createdAt, service.CreatedAt);
    }

    [Fact]
    public void Constructor_WhenIdIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreateService(id: Guid.Empty));
    }

    [Fact]
    public void Constructor_WhenNameIsBlank_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreateService(name: "   "));
    }

    [Fact]
    public void Constructor_WhenDefaultAmountIsNegativeForNormalService_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreateService(type: ServiceType.Recurring, defaultAmount: -0.01m));
    }

    [Fact]
    public void Constructor_WhenDefaultAmountIsNegativeForAdjustmentService_AllowsCreation()
    {
        var service = CreateService(type: ServiceType.Adjustment, defaultAmount: -250.00m);

        Assert.Equal(ServiceType.Adjustment, service.Type);
        Assert.Equal(-250.00m, service.DefaultAmount);
    }

    private static Service CreateService(
        Guid? id = null,
        string name = "Maintenance",
        ServiceType type = ServiceType.Recurring,
        decimal defaultAmount = 1200.00m) =>
        new(
            id ?? Guid.NewGuid(),
            name,
            "Standard service",
            type,
            defaultAmount,
            isReservable: false,
            isActive: true,
            new DateTimeOffset(2026, 8, 20, 9, 0, 0, TimeSpan.Zero));
}
