export type Priority = 'low' | 'medium' | 'high' | 'critical';
export type Status = 'open' | 'in_progress' | 'resolved' | 'closed';

export interface ServiceRequest {
  id: string;
  title: string;
  description: string;
  requestorEmail: string;
  priority: Priority;
  status: Status;
  createdAt: string;
  updatedAt: string;
}

export interface CreateServiceRequestDto {
  title: string;
  description: string;
  requestorEmail: string;
  priority: Priority;
}

export interface UpdateStatusDto {
  status: Status;
}
