using Xunit;
using Hestia.Domain.Billing;

namespace Hestia.Tests.Domain.Billing;

public sealed class ChargeTests
{
    [Fact]
    public void Constructor_WhenAmountIsPositive_CreatesPendingChargeWithoutPayment()
    {
        var charge = CreateCharge(amount: 250.00m);

        Assert.Equal(250.00m, charge.OriginalAmount);
        Assert.Equal(250.00m, charge.Amount);
        Assert.Equal(ChargeStatus.Pending, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Constructor_WhenAmountIsZero_CreatesWaivedCharge()
    {
        var charge = CreateCharge(amount: 0m);

        Assert.Equal(0m, charge.OriginalAmount);
        Assert.Equal(0m, charge.Amount);
        Assert.Equal(ChargeStatus.Waived, charge.Status);
    }

    [Fact]
    public void Constructor_WhenAmountIsNegative_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreateCharge(amount: -0.01m));
    }

    [Fact]
    public void Constructor_WhenBillingPeriodIsInvalid_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreateCharge(billingPeriod: 202613));
    }

    [Fact]
    public void Pay_WhenAmountMatchesPendingCharge_CreatesPaymentAndSettlesCharge()
    {
        var charge = CreateCharge(amount: 250.00m);
        var paymentDate = new DateTimeOffset(2026, 8, 5, 15, 30, 0, TimeSpan.Zero);
        var createdAt = new DateTimeOffset(2026, 8, 5, 15, 31, 0, TimeSpan.Zero);
        var createdBy = Guid.NewGuid();

        var payment = charge.Pay(
            paymentDate,
            250.00m,
            PaymentMethod.Transfer,
            "SPEI-12345",
            "August maintenance charge.",
            createdAt,
            createdBy);

        Assert.Equal(ChargeStatus.Paid, charge.Status);
        Assert.Same(payment, charge.Payment);
        Assert.Equal(charge.Id, payment.ChargeId);
        Assert.Equal(paymentDate, payment.PaymentDate);
        Assert.Equal(250.00m, payment.Amount);
        Assert.Equal(PaymentMethod.Transfer, payment.PaymentMethod);
        Assert.Equal("SPEI-12345", payment.Reference);
        Assert.Equal("August maintenance charge.", payment.Notes);
        Assert.Equal(createdAt, payment.CreatedAt);
        Assert.Equal(createdBy, payment.CreatedBy);
    }

    [Theory]
    [InlineData(249.99)]
    [InlineData(250.01)]
    public void Pay_WhenAmountDoesNotMatchCurrentChargeAmount_ThrowsAndDoesNotMutateCharge(decimal paymentAmount)
    {
        var charge = CreateCharge(amount: 250.00m);

        Assert.Throws<ArgumentException>(() => Pay(charge, paymentAmount));

        Assert.Equal(ChargeStatus.Pending, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Pay_WhenChargeWasAlreadyPaid_ThrowsAndKeepsOriginalPayment()
    {
        var charge = CreateCharge(amount: 250.00m);
        var originalPayment = Pay(charge, 250.00m);

        Assert.Throws<InvalidOperationException>(() => Pay(charge, 250.00m));

        Assert.Equal(ChargeStatus.Paid, charge.Status);
        Assert.Same(originalPayment, charge.Payment);
    }

    [Fact]
    public void Waive_WhenChargeIsPending_SetsAmountToZeroAndPreservesOriginalAmount()
    {
        var charge = CreateCharge(amount: 250.00m);

        charge.Waive();

        Assert.Equal(250.00m, charge.OriginalAmount);
        Assert.Equal(0m, charge.Amount);
        Assert.Equal(ChargeStatus.Waived, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Waive_WhenChargeWasAlreadyWaived_ThrowsAndKeepsState()
    {
        var charge = CreateCharge(amount: 250.00m);
        charge.Waive();

        Assert.Throws<InvalidOperationException>(charge.Waive);

        Assert.Equal(250.00m, charge.OriginalAmount);
        Assert.Equal(0m, charge.Amount);
        Assert.Equal(ChargeStatus.Waived, charge.Status);
    }

    [Fact]
    public void Pay_WhenChargeIsWaived_ThrowsAndDoesNotCreatePayment()
    {
        var charge = CreateCharge(amount: 250.00m);
        charge.Waive();

        Assert.Throws<InvalidOperationException>(() => Pay(charge, 0m));

        Assert.Equal(ChargeStatus.Waived, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Cancel_WhenChargeIsPending_SetsCancelledAndPreservesFinancialData()
    {
        var charge = CreateCharge(amount: 250.00m);

        charge.Cancel();

        Assert.Equal(250.00m, charge.OriginalAmount);
        Assert.Equal(250.00m, charge.Amount);
        Assert.Equal(ChargeStatus.Cancelled, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Cancel_WhenChargeWasAlreadyCancelled_ThrowsAndKeepsState()
    {
        var charge = CreateCharge(amount: 250.00m);
        charge.Cancel();

        Assert.Throws<InvalidOperationException>(charge.Cancel);

        Assert.Equal(ChargeStatus.Cancelled, charge.Status);
        Assert.Equal(250.00m, charge.Amount);
    }

    [Fact]
    public void Pay_WhenChargeIsCancelled_ThrowsAndDoesNotCreatePayment()
    {
        var charge = CreateCharge(amount: 250.00m);
        charge.Cancel();

        Assert.Throws<InvalidOperationException>(() => Pay(charge, 250.00m));

        Assert.Equal(ChargeStatus.Cancelled, charge.Status);
        Assert.Null(charge.Payment);
    }

    [Fact]
    public void Waive_WhenChargeIsCancelled_ThrowsAndPreservesAmount()
    {
        var charge = CreateCharge(amount: 250.00m);
        charge.Cancel();

        Assert.Throws<InvalidOperationException>(charge.Waive);

        Assert.Equal(250.00m, charge.Amount);
        Assert.Equal(ChargeStatus.Cancelled, charge.Status);
    }

    [Fact]
    public void Cancel_WhenChargeWasPaid_ThrowsAndPreservesPayment()
    {
        var charge = CreateCharge(amount: 250.00m);
        var payment = Pay(charge, 250.00m);

        Assert.Throws<InvalidOperationException>(charge.Cancel);

        Assert.Equal(ChargeStatus.Paid, charge.Status);
        Assert.Same(payment, charge.Payment);
    }

    private static Charge CreateCharge(decimal amount = 250.00m, int billingPeriod = 202608) =>
        new(
            id: Guid.NewGuid(),
            departmentId: Guid.NewGuid(),
            serviceId: Guid.NewGuid(),
            amount: amount,
            billingPeriod: billingPeriod,
            dueDate: new DateOnly(2026, 8, 10),
            serviceType: ServiceType.Extraordinary,
            createdAt: new DateTimeOffset(2026, 8, 1, 9, 0, 0, TimeSpan.Zero),
            createdBy: Guid.NewGuid());

    private static Payment Pay(Charge charge, decimal amount) =>
        charge.Pay(
            paymentDate: new DateTimeOffset(2026, 8, 5, 15, 30, 0, TimeSpan.Zero),
            amount: amount,
            paymentMethod: PaymentMethod.Transfer,
            reference: "SPEI-12345",
            notes: "August maintenance charge.",
            createdAt: new DateTimeOffset(2026, 8, 5, 15, 31, 0, TimeSpan.Zero),
            createdBy: Guid.NewGuid());
}
