using Scalar.AspNetCore;


public partial class Program
{
    private static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Add services to the container.

        builder.Services.AddControllers();
        builder.Services.AddSingleton<IConfiguration>(builder.Configuration);
        builder.Services.AddTransient<Hestia.Application.Repositories.IChargeRepository, Hestia.Infrastructure.Postgres.ChargeRepository>();
        builder.Services.AddTransient<Hestia.Application.Repositories.IOwnerRepository, Hestia.Infrastructure.Postgres.OwnerRepository>();
        builder.Services.AddTransient<Hestia.Application.Repositories.IDepartmentRepository, Hestia.Infrastructure.Postgres.DepartmentRepository>();
        builder.Services.AddTransient<Hestia.Application.Repositories.IDepartmentOwnerHistoryRepository, Hestia.Infrastructure.Postgres.DepartmentOwnerHistoryRepository>();
        builder.Services.AddTransient<Hestia.Application.Repositories.IUserRepository, Hestia.Infrastructure.Postgres.UserRepository>();
        builder.Services.AddTransient<Hestia.Application.Services.ChargeService>();
        // Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
        builder.Services.AddOpenApi();

        var app = builder.Build();

        // Configure the HTTP request pipeline.
        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
            app.MapScalarApiReference();
        }

        app.UseHttpsRedirection();

        app.UseAuthorization();

        app.MapControllers();

        app.Run();
    }
}
