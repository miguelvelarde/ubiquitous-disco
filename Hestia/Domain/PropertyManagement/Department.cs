namespace Hestia.Domain.PropertyManagement;

public sealed class Department
{
    public Department(
        Guid id,
        Guid ownerId,
        string building,
        string number,
        DepartmentStatus status,
        DateTimeOffset createdAt)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A department requires an identifier.", nameof(id));
        }

        if (ownerId == Guid.Empty)
        {
            throw new ArgumentException("A department requires an owner identifier.", nameof(ownerId));
        }

        if (string.IsNullOrWhiteSpace(building))
        {
            throw new ArgumentException("A department requires a building.", nameof(building));
        }

        if (string.IsNullOrWhiteSpace(number))
        {
            throw new ArgumentException("A department requires a number.", nameof(number));
        }

        Id = id;
        OwnerId = ownerId;
        Building = building;
        Number = number;
        Status = status;
        CreatedAt = createdAt;
    }

    public Guid Id { get; }

    public Guid OwnerId { get; private set; }

    public string Building { get; }

    public string Number { get; }

    public DepartmentStatus Status { get; private set; }

    public DateTimeOffset CreatedAt { get; }

    public void ChangeOwner(Guid ownerId)
    {
        if (ownerId == Guid.Empty)
        {
            throw new ArgumentException("A department requires an owner identifier.", nameof(ownerId));
        }

        OwnerId = ownerId;
    }

    public void Activate()
    {
        Status = DepartmentStatus.Active;
    }

    public void Deactivate()
    {
        Status = DepartmentStatus.Inactive;
    }
}
