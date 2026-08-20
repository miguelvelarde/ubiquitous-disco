using Hestia.Domain.Billing;
using Xunit;

namespace Hestia.Tests.Domain.Billing;

public sealed class DepartmentServiceTests
{
    [Fact]
    public void Constructor_WhenIdentifiersAreValid_CreatesAssociation()
    {
        var departmentId = Guid.NewGuid();
        var serviceId = Guid.NewGuid();

        var association = new DepartmentService(departmentId, serviceId);

        Assert.Equal(departmentId, association.DepartmentId);
        Assert.Equal(serviceId, association.ServiceId);
    }

    [Fact]
    public void Constructor_WhenDepartmentIdIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => new DepartmentService(Guid.Empty, Guid.NewGuid()));
    }

    [Fact]
    public void Constructor_WhenServiceIdIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => new DepartmentService(Guid.NewGuid(), Guid.Empty));
    }
}
