namespace Hestia.Domain.PropertyManagement;

public sealed class DepartmentOwnerHistory
{
    public DepartmentOwnerHistory(
        Guid id,
        Guid departmentId,
        Guid ownerId,
        DateOnly startDate,
        DateOnly? endDate,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A department owner history record requires an identifier.", nameof(id));
        }

        if (departmentId == Guid.Empty)
        {
            throw new ArgumentException("A department owner history record requires a department identifier.", nameof(departmentId));
        }

        if (ownerId == Guid.Empty)
        {
            throw new ArgumentException("A department owner history record requires an owner identifier.", nameof(ownerId));
        }

        if (createdBy == Guid.Empty)
        {
            throw new ArgumentException("A department owner history record requires its creator identifier.", nameof(createdBy));
        }

        if (endDate is not null && endDate.Value < startDate)
        {
            throw new ArgumentException("Ownership end date cannot be earlier than its start date.", nameof(endDate));
        }

        Id = id;
        DepartmentId = departmentId;
        OwnerId = ownerId;
        StartDate = startDate;
        EndDate = endDate;
        CreatedAt = createdAt;
        CreatedBy = createdBy;
    }

    public Guid Id { get; }

    public Guid DepartmentId { get; }

    public Guid OwnerId { get; }

    public DateOnly StartDate { get; }

    public DateOnly? EndDate { get; private set; }

    public DateTimeOffset CreatedAt { get; }

    public Guid CreatedBy { get; }

    public void Close(DateOnly endDate)
    {
        if (EndDate is not null)
        {
            throw new InvalidOperationException("Ownership history is already closed.");
        }

        if (endDate < StartDate)
        {
            throw new ArgumentException("Ownership end date cannot be earlier than its start date.", nameof(endDate));
        }

        EndDate = endDate;
    }
}
