namespace Hestia.Domain.Billing;

public sealed class DepartmentService
{
    public DepartmentService(Guid departmentId, Guid serviceId)
    {
        if (departmentId == Guid.Empty) throw new ArgumentException("A department service requires a department identifier.", nameof(departmentId));
        if (serviceId == Guid.Empty) throw new ArgumentException("A department service requires a service identifier.", nameof(serviceId));
        DepartmentId = departmentId;
        ServiceId = serviceId;
    }

    public Guid DepartmentId { get; }
    public Guid ServiceId { get; }
}