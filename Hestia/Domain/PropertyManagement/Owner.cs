namespace Hestia.Domain.PropertyManagement;

public sealed class Owner
{
    public Owner(
        Guid id,
        string name,
        string? email,
        string? phone,
        DateTimeOffset createdAt)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("An owner requires an identifier.", nameof(id));
        }

        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("An owner requires a name.", nameof(name));
        }

        Id = id;
        Name = name;
        Email = string.IsNullOrWhiteSpace(email) ? null : email;
        Phone = string.IsNullOrWhiteSpace(phone) ? null : phone;
        CreatedAt = createdAt;
    }

    public Guid Id { get; }

    public string Name { get; }

    public string? Email { get; }

    public string? Phone { get; }

    public DateTimeOffset CreatedAt { get; }
}
