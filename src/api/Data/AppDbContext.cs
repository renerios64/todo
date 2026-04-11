using Microsoft.EntityFrameworkCore;
using ServiceRequestApi.Models;

namespace ServiceRequestApi.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ServiceRequest> ServiceRequests => Set<ServiceRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ServiceRequest>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Priority).HasConversion<string>();
            e.Property(x => x.Status).HasConversion<string>();
        });
    }
}
