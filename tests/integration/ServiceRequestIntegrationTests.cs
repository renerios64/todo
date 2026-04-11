using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using ServiceRequestApi.DTOs;
using ServiceRequestApi.Models;

namespace ServiceRequestApi.IntegrationTests;

/// <summary>
/// Integration tests: real Postgres via Testcontainers, real EF Core SQL.
///
/// Why integration tests on top of unit tests?
/// - InMemory DB skips SQL translation — your LINQ might be valid C# but
///   generate bad SQL that only fails against a real database.
/// - Constraints (NOT NULL, FK, unique indexes) only enforce in real Postgres.
/// - String comparisons, case sensitivity, collation — all real Postgres behavior.
/// - EF Core migrations and schema are proven end-to-end.
///
/// IClassFixture<PostgresApiFactory> means ONE container per test class.
/// The container starts before the first test and stops after the last.
/// </summary>
public class ServiceRequestIntegrationTests : IClassFixture<PostgresApiFactory>
{
    private readonly HttpClient _client;

    // Shared JSON options — must match the API's JsonStringEnumConverter(SnakeCaseLower)
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower) }
    };

    public ServiceRequestIntegrationTests(PostgresApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    // ─── Health ────────────────────────────────────────────────────────────

    [Fact]
    public async Task HealthEndpoint_Returns200()
    {
        var res = await _client.GetAsync("/api/health");
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    // ─── Create ────────────────────────────────────────────────────────────

    [Fact]
    public async Task CreateRequest_PersistsToRealPostgres()
    {
        var created = await CreateSampleRequest("Postgres test request");

        Assert.NotEqual(Guid.Empty, created!.Id);
        Assert.Equal("Postgres test request", created.Title);
        Assert.Equal("open", created.Status);
    }

    [Fact]
    public async Task CreateRequest_Then_GetById_ReturnsSameData()
    {
        var created = await CreateSampleRequest("Roundtrip test");

        var fetched = await _client.GetFromJsonAsync<ServiceRequestDto>(
            $"/api/service-requests/{created!.Id}", JsonOpts);

        Assert.NotNull(fetched);
        Assert.Equal(created.Id, fetched.Id);
        Assert.Equal("Roundtrip test", fetched.Title);
    }

    // ─── List ──────────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAll_ReturnsCreatedRequests()
    {
        await CreateSampleRequest("List test item");

        var list = await _client.GetFromJsonAsync<List<ServiceRequestDto>>(
            "/api/service-requests", JsonOpts);

        Assert.NotNull(list);
        Assert.True(list.Count > 0);
    }

    // ─── Status update ─────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateStatus_ChangesStatus_InRealDb()
    {
        var created = await CreateSampleRequest("Status test");

        var patch = new UpdateStatusDto(Status.InProgress);
        var patchRes = await _client.PatchAsJsonAsync(
            $"/api/service-requests/{created!.Id}/status", patch, JsonOpts);

        Assert.Equal(HttpStatusCode.OK, patchRes.StatusCode);

        var fetched = await _client.GetFromJsonAsync<ServiceRequestDto>(
            $"/api/service-requests/{created.Id}", JsonOpts);

        Assert.Equal("in_progress", fetched!.Status);
    }

    // ─── Not found ─────────────────────────────────────────────────────────

    [Fact]
    public async Task GetById_NonexistentId_Returns404()
    {
        var res = await _client.GetAsync($"/api/service-requests/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    // ─── Helpers ───────────────────────────────────────────────────────────

    private async Task<ServiceRequestDto?> CreateSampleRequest(string title)
    {
        var dto = new CreateServiceRequestDto(
            title,
            "Integration test description",
            "test@example.com",
            Priority.High
        );

        var res = await _client.PostAsJsonAsync("/api/service-requests", dto, JsonOpts);
        res.EnsureSuccessStatusCode();
        return await res.Content.ReadFromJsonAsync<ServiceRequestDto>(JsonOpts);
    }
}
