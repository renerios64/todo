namespace ServiceRequestApi.Models;

public enum Priority { Low, Medium, High, Critical }
public enum Status  { Open, InProgress, Resolved, Closed }

public class ServiceRequest
{
    public Guid   Id             { get; set; } = Guid.NewGuid();
    public string Title          { get; set; } = string.Empty;
    public string Description    { get; set; } = string.Empty;
    public string RequestorEmail { get; set; } = string.Empty;
    public Priority Priority     { get; set; } = Priority.Medium;
    public Status   Status       { get; set; } = Status.Open;
    public DateTime CreatedAt    { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt    { get; set; } = DateTime.UtcNow;
}
