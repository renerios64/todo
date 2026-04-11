namespace ServiceRequestApi.DTOs;

public record CreateServiceRequestDto(
    string Title,
    string Description,
    string RequestorEmail,
    Models.Priority Priority
);

public record UpdateStatusDto(Models.Status Status);

public record ServiceRequestDto(
    Guid   Id,
    string Title,
    string Description,
    string RequestorEmail,
    string Priority,
    string Status,
    DateTime CreatedAt,
    DateTime UpdatedAt
);
