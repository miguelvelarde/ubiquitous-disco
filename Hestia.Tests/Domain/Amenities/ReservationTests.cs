using Hestia.Domain.Amenities;
using Xunit;

namespace Hestia.Tests.Domain.Amenities;

public sealed class ReservationTests
{
    [Fact]
    public void Constructor_WhenStateIsValid_CreatesConfirmedReservation()
    {
        var id = Guid.NewGuid();
        var departmentId = Guid.NewGuid();
        var serviceId = Guid.NewGuid();
        var startDateTime = new DateTimeOffset(2026, 8, 20, 10, 0, 0, TimeSpan.Zero);
        var endDateTime = new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);
        var createdAt = new DateTimeOffset(2026, 8, 18, 9, 0, 0, TimeSpan.Zero);
        var createdBy = Guid.NewGuid();

        var reservation = new Reservation(
            id,
            departmentId,
            serviceId,
            startDateTime,
            endDateTime,
            null,
            createdAt,
            createdBy);

        Assert.Equal(id, reservation.Id);
        Assert.Equal(departmentId, reservation.DepartmentId);
        Assert.Equal(serviceId, reservation.ServiceId);
        Assert.Equal(startDateTime, reservation.StartDateTime);
        Assert.Equal(endDateTime, reservation.EndDateTime);
        Assert.Equal(ReservationStatus.Confirmed, reservation.Status);
        Assert.Equal(createdAt, reservation.CreatedAt);
        Assert.Equal(createdBy, reservation.CreatedBy);
    }

    [Fact]
    public void Constructor_WhenEndIsEqualToStart_ThrowsArgumentException()
    {
        var startDateTime = new DateTimeOffset(2026, 8, 20, 10, 0, 0, TimeSpan.Zero);

        Assert.Throws<ArgumentException>(() => CreateReservation(startDateTime, startDateTime));
    }

    [Fact]
    public void Constructor_WhenEndIsBeforeStart_ThrowsArgumentException()
    {
        var startDateTime = new DateTimeOffset(2026, 8, 20, 10, 0, 0, TimeSpan.Zero);
        var endDateTime = new DateTimeOffset(2026, 8, 20, 9, 0, 0, TimeSpan.Zero);

        Assert.Throws<ArgumentException>(() => CreateReservation(startDateTime, endDateTime));
    }

    [Fact]
    public void Constructor_WhenServiceIdIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreateReservation(serviceId: Guid.Empty));
    }

    [Fact]
    public void Constructor_WhenCreatedByIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreateReservation(createdBy: Guid.Empty));
    }

    [Fact]
    public void Constructor_WhenNotesAreBlank_UsesDefaultNotes()
    {
        var reservation = CreateReservation(notes: " ");

        Assert.Equal("Sin notas", reservation.Notes);
    }

    [Fact]
    public void Cancel_WhenReservationIsConfirmed_SetsCancelled()
    {
        var reservation = CreateReservation();

        reservation.Cancel();

        Assert.Equal(ReservationStatus.Cancelled, reservation.Status);
    }

    [Fact]
    public void Cancel_WhenReservationWasAlreadyCancelled_ThrowsInvalidOperationException()
    {
        var reservation = CreateReservation();
        reservation.Cancel();

        Assert.Throws<InvalidOperationException>(reservation.Cancel);

        Assert.Equal(ReservationStatus.Cancelled, reservation.Status);
    }

    private static Reservation CreateReservation(
        DateTimeOffset? startDateTime = null,
        DateTimeOffset? endDateTime = null,
        Guid? serviceId = null,
        Guid? createdBy = null,
        string? notes = null) =>
        new(
            id: Guid.NewGuid(),
            departmentId: Guid.NewGuid(),
            serviceId: serviceId ?? Guid.NewGuid(),
            startDateTime: startDateTime ?? new DateTimeOffset(2026, 8, 20, 10, 0, 0, TimeSpan.Zero),
            endDateTime: endDateTime ?? new DateTimeOffset(2026, 8, 20, 12, 0, 0, TimeSpan.Zero),
            notes: notes,
            createdAt: new DateTimeOffset(2026, 8, 18, 9, 0, 0, TimeSpan.Zero),
            createdBy: createdBy ?? Guid.NewGuid());
}
