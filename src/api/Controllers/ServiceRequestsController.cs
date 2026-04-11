using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ServiceRequestApi.Data;
using ServiceRequestApi.DTOs;
using ServiceRequestApi.Models;

namespace ServiceRequestApi.Controllers;

[ApiController]
[Route("api/service-requests")]
public class ServiceRequestsController(AppDbContext db) : ControllerBase
{
    private static ServiceRequestDto ToDto(ServiceRequest r) => new(
        r.Id, r.Title, r.Description, r.RequestorEmail,
        r.Priority.ToString().ToLower(),
        r.Status.ToString().ToLower().Replace("inprogress", "in_progress"),
        r.CreatedAt, r.UpdatedAt
    );

    // GET /api/service-requests
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search,
        [FromQuery] string? status,
        [FromQuery] string? priority)
    {
        var query = db.ServiceRequests.AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(r =>
                r.Title.Contains(search) || r.Description.Contains(search) ||
                r.RequestorEmail.Contains(search));

        if (!string.IsNullOrWhiteSpace(status) &&
            Enum.TryParse<Status>(status.Replace("_", ""), true, out var s))
            query = query.Where(r => r.Status == s);

        if (!string.IsNullOrWhiteSpace(priority) &&
            Enum.TryParse<Priority>(priority, true, out var p))
            query = query.Where(r => r.Priority == p);

        var results = await query
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => ToDto(r))
            .ToListAsync();

        return Ok(results);
    }

    // GET /api/service-requests/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var r = await db.ServiceRequests.FindAsync(id);
        return r is null ? NotFound() : Ok(ToDto(r));
    }

    // POST /api/service-requests
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateServiceRequestDto dto)
    {
        var r = new ServiceRequest
        {
            Title          = dto.Title,
            Description    = dto.Description,
            RequestorEmail = dto.RequestorEmail,
            Priority       = dto.Priority,
        };
        db.ServiceRequests.Add(r);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = r.Id }, ToDto(r));
    }

    // PATCH /api/service-requests/{id}/status
    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateStatusDto dto)
    {
        var r = await db.ServiceRequests.FindAsync(id);
        if (r is null) return NotFound();
        r.Status    = dto.Status;
        r.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return Ok(ToDto(r));
    }
}
