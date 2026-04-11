using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Testcontainers.PostgreSql;

namespace ServiceRequestApi.IntegrationTests;

/// <summary>
/// Spins up a real Postgres container once per test class, wires it into
/// the WebApplicationFactory, then tears it down after all tests finish.
///
/// IAsyncLifetime gives us async InitializeAsync / DisposeAsync — needed
/// because starting a Docker container is an async I/O operation.
/// </summary>
public class PostgresApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    // Testcontainers builds and starts a throwaway postgres:16 container.
    // It picks a random free host port automatically — no port conflicts.
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .WithDatabase("integration_tests")
        .WithUsername("testuser")
        .WithPassword("testpassword")
        .Build();

    // Called by xUnit before any test in the class runs
    public async Task InitializeAsync() => await _postgres.StartAsync();

    // Called by xUnit after all tests in the class finish
    public new async Task DisposeAsync() => await _postgres.DisposeAsync();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Inject the container's connection string so Program.cs uses it
        // directly — this means it registers Npgsql only (no InMemory at all),
        // avoiding the "two providers" conflict.
        builder.UseSetting(
            "ConnectionStrings:DefaultConnection",
            _postgres.GetConnectionString());
    }
}
