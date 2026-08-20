namespace Hestia.Domain.Security;

public sealed class User
{
    public User(
        Guid id,
        string username,
        string passwordHash,
        UserRole role,
        DateTimeOffset createdAt)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A user requires an identifier.", nameof(id));
        }

        if (string.IsNullOrWhiteSpace(username))
        {
            throw new ArgumentException("A user requires a username.", nameof(username));
        }

        if (string.IsNullOrWhiteSpace(passwordHash))
        {
            throw new ArgumentException("A user requires a password hash.", nameof(passwordHash));
        }

        Id = id;
        Username = username;
        PasswordHash = passwordHash;
        Role = role;
        CreatedAt = createdAt;
    }

    public Guid Id { get; }

    public string Username { get; }

    public string PasswordHash { get; }

    public UserRole Role { get; }

    public DateTimeOffset CreatedAt { get; }
}
