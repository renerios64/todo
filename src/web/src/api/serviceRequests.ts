import { apiClient } from './client';
import type {
  ServiceRequest,
  CreateServiceRequestDto,
  UpdateStatusDto,
} from '../types/serviceRequest';

export async function getServiceRequests(params?: {
  search?: string;
  status?: string;
  priority?: string;
}): Promise<ServiceRequest[]> {
  const { data } = await apiClient.get<ServiceRequest[]>('/service-requests', { params });
  return data;
}

export async function getServiceRequest(id: string): Promise<ServiceRequest> {
  const { data } = await apiClient.get<ServiceRequest>(`/service-requests/${id}`);
  return data;
}

export async function createServiceRequest(
  dto: CreateServiceRequestDto,
): Promise<ServiceRequest> {
  const { data } = await apiClient.post<ServiceRequest>('/service-requests', dto);
  return data;
}

export async function updateServiceRequestStatus(
  id: string,
  dto: UpdateStatusDto,
): Promise<ServiceRequest> {
  const { data } = await apiClient.patch<ServiceRequest>(
    `/service-requests/${id}/status`,
    dto,
  );
  return data;
}
