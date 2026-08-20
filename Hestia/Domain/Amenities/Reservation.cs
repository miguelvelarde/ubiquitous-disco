namespace Hestia.Domain.Amenities;

/// <summary>
/// Aggregate root for a confirmed amenity reservation.
/// </summary>
public sealed class Reservation
{
    public Reservation(
        Guid id,
        Guid? departmentId,
        Guid serviceId,
        DateTimeOffset startDateTime,
        DateTimeOffset endDateTime,
        string? notes,
        DateTimeOffset createdAt,
        Guid createdBy)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires an identifier.", nameof(id));
        }

        if (serviceId == Guid.Empty)
        {
            throw new ArgumentException("A reservation requires a service identifier.", nameof(serviceId));
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
        DepartmentId = departmentId;
        ServiceId = serviceId;
        StartDateTime = startDateTime;
        EndDateTime = endDateTime;
        Status = ReservationStatus.Confirmed;
        Notes = string.IsNullOrWhiteSpace(notes) ? "Sin notas" : notes;
        CreatedAt = createdAt;
        CreatedBy = createdBy;
    }

    public Guid Id { get; }

    public Guid? DepartmentId { get; }

    public Guid ServiceId { get; }

    public DateTimeOffset StartDateTime { get; }

    public DateTimeOffset EndDateTime { get; }

    public ReservationStatus Status { get; private set; }

    public string Notes { get; }

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
