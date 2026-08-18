namespace Hestia.Domain.Amenities;

/// <summary>
/// Aggregate root for a confirmed amenity reservation.
/// </summary>
public sealed class Reservation
{
    public Reservation(
        Guid id,
        Guid amenityId,
        Guid departmentId,
        Guid serviceCatalogId,
        DateTimeOffset startDateTime,
        DateTimeOffset endDateTime,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires an identifier.", nameof(id));
        }

        if (amenityId == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires an amenity identifier.", nameof(amenityId));
        }

        if (departmentId == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires a department identifier.", nameof(departmentId));
        }

        if (serviceCatalogId == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires a service catalog identifier.", nameof(serviceCatalogId));
        }

        if (endDateTime <= startDateTime)
        {
            throw new ArgumentException("Reservation end date and time must be after its start.", nameof(endDateTime));
        }

        if (createdBy == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires its creator identifier.", nameof(createdBy));
        }

        Id = id;
        AmenityId = amenityId;
        DepartmentId = departmentId;
        ServiceCatalogId = serviceCatalogId;
        StartDateTime = startDateTime;
        EndDateTime = endDateTime;
        Status = ReservationStatus.Confirmed;
        CreatedAt = createdAt;
        CreatedBy = createdBy;
    }

    public Guid Id { get; }

    public Guid AmenityId { get; }

    public Guid DepartmentId { get; }

    public Guid ServiceCatalogId { get; }

    public DateTimeOffset StartDateTime { get; }

    public DateTimeOffset EndDateTime { get; }

    public ReservationStatus Status { get; private set; }

    public DateTimeOffset CreatedAt { get; }

    public Guid CreatedBy { get; }

    public void Cancel()
    {
        if (Status != ReservationStatus.Confirmed)
        {
            throw new InvalidOperationException("Only confirmed reservations can be cancelled.");
        }

        Status = ReservationStatus.Cancelled;
    }
}
