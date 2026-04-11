using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using ServiceRequestApi.DTOs;

namespace ServiceRequestApi.Tests;

public class HealthTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task Health_Returns200() =>
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/health")).StatusCode);

    [Fact]
    public async Task Ready_Returns200() =>
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/ready")).StatusCode);
}

public class ServiceRequestsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower) }
    };

    private static CreateServiceRequestDto SampleDto(string title = "Test Request") => new(
        title, "A description", "user@example.com", Models.Priority.High);

    [Fact]
    public async Task GetAll_ReturnsEmptyList()
    {
        var result = await _client.GetFromJsonAsync<List<ServiceRequestDto>>("/api/service-requests", JsonOpts);
        Assert.NotNull(result);
    }

    [Fact]
    public async Task Create_Returns201WithLocation()
    {
        var response = await _client.PostAsJsonAsync("/api/service-requests", SampleDto(), JsonOpts);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(response.Headers.Location);
    }

    [Fact]
    public async Task Create_ThenGetById_ReturnsRequest()
    {
        var created = await (await _client.PostAsJsonAsync("/api/service-requests", SampleDto("My Request"), JsonOpts))
            .Content.ReadFromJsonAsync<ServiceRequestDto>(JsonOpts);

        var fetched = await _client.GetFromJsonAsync<ServiceRequestDto>(
            $"/api/service-requests/{created!.Id}", JsonOpts);

        Assert.Equal("My Request", fetched!.Title);
        Assert.Equal("user@example.com", fetched.RequestorEmail);
        Assert.Equal("open", fetched.Status);
    }

    [Fact]
    public async Task UpdateStatus_ChangesStatus()
    {
        var created = await (await _client.PostAsJsonAsync("/api/service-requests", SampleDto(), JsonOpts))
            .Content.ReadFromJsonAsync<ServiceRequestDto>(JsonOpts);

        var updated = await (await _client.PatchAsJsonAsync(
                $"/api/service-requests/{created!.Id}/status",
                new UpdateStatusDto(Models.Status.Resolved), JsonOpts))
            .Content.ReadFromJsonAsync<ServiceRequestDto>(JsonOpts);

        Assert.Equal("resolved", updated!.Status);
    }

    [Fact]
    public async Task GetById_NotFound_Returns404()
    {
        var response = await _client.GetAsync($"/api/service-requests/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetAll_Search_FiltersResults()
    {
        await _client.PostAsJsonAsync("/api/service-requests", SampleDto("Unique-XYZ-Title"), JsonOpts);
        await _client.PostAsJsonAsync("/api/service-requests", SampleDto("Another Request"), JsonOpts);

        var results = await _client.GetFromJsonAsync<List<ServiceRequestDto>>(
            "/api/service-requests?search=Unique-XYZ", JsonOpts);

        Assert.NotEmpty(results!);
        Assert.Contains(results!, r => r.Title.Contains("Unique-XYZ"));
    }
}
