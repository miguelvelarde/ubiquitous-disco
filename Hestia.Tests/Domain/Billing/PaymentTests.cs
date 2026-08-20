using Hestia.Domain.Billing;
using Xunit;

namespace Hestia.Tests.Domain.Billing;

public sealed class PaymentTests
{
    [Fact]
    public void Constructor_WhenStateIsValid_CreatesPayment()
    {
        var id = Guid.NewGuid();
        var chargeId = Guid.NewGuid();
        var paymentDate = new DateTimeOffset(2026, 8, 20, 11, 0, 0, TimeSpan.Zero);
        var createdAt = new DateTimeOffset(2026, 8, 20, 11, 1, 0, TimeSpan.Zero);
        var createdBy = Guid.NewGuid();

        var payment = new Payment(
            id,
            chargeId,
            paymentDate,
            1200.00m,
            PaymentMethod.Card,
            "POS-55421",
            "Paid in lobby terminal.",
            createdAt,
            createdBy);

        Assert.Equal(id, payment.Id);
        Assert.Equal(chargeId, payment.ChargeId);
        Assert.Equal(paymentDate, payment.PaymentDate);
        Assert.Equal(1200.00m, payment.Amount);
        Assert.Equal(PaymentMethod.Card, payment.PaymentMethod);
        Assert.Equal("POS-55421", payment.Reference);
        Assert.Equal("Paid in lobby terminal.", payment.Notes);
        Assert.Equal(createdAt, payment.CreatedAt);
        Assert.Equal(createdBy, payment.CreatedBy);
    }

    [Fact]
    public void Constructor_WhenNotesAreBlank_UsesDefaultNotes()
    {
        var payment = CreatePayment(notes: "   ");

        Assert.Equal("Sin notas", payment.Notes);
    }

    [Fact]
    public void Constructor_WhenAmountIsZero_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreatePayment(amount: 0m));
    }

    [Fact]
    public void Constructor_WhenReferenceIsBlank_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreatePayment(reference: ""));
    }

    [Fact]
    public void Constructor_WhenCreatedByIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreatePayment(createdBy: Guid.Empty));
    }

    [Fact]
    public void Constructor_WhenChargeIdIsEmpty_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CreatePayment(chargeId: Guid.Empty));
    }

    [Fact]
    public void Constructor_WhenPaymentMethodIsInvalid_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreatePayment(paymentMethod: (PaymentMethod)999));
    }

    private static Payment CreatePayment(
        Guid? id = null,
        Guid? chargeId = null,
        decimal amount = 1200.00m,
        PaymentMethod paymentMethod = PaymentMethod.Transfer,
        string reference = "SPEI-9988",
        string? notes = "Paid from bank app.",
        Guid? createdBy = null) =>
        new(
            id ?? Guid.NewGuid(),
            chargeId ?? Guid.NewGuid(),
            new DateTimeOffset(2026, 8, 20, 11, 0, 0, TimeSpan.Zero),
            amount,
            paymentMethod,
            reference,
            notes,
            new DateTimeOffset(2026, 8, 20, 11, 1, 0, TimeSpan.Zero),
            createdBy ?? Guid.NewGuid());
}
