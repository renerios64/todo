import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useParams, Link } from 'react-router-dom';
import { getServiceRequest, updateServiceRequestStatus } from '../api/serviceRequests';
import { PriorityBadge, StatusBadge } from '../components/Badges';
import { StatusUpdater } from '../components/StatusUpdater';
import type { Status } from '../types/serviceRequest';

export function RequestDetailPage() {
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();

  const { data, isLoading, isError } = useQuery({
    queryKey: ['service-request', id],
    queryFn: () => getServiceRequest(id!),
    enabled: !!id,
  });

  const mutation = useMutation({
    mutationFn: (status: Status) => updateServiceRequestStatus(id!, { status }),
    onSuccess: (updated) => {
      queryClient.setQueryData(['service-request', id], updated);
      queryClient.invalidateQueries({ queryKey: ['service-requests'] });
    },
  });

  if (isLoading) return <p>Loading…</p>;
  if (isError || !data) return <p style={{ color: 'red' }}>Request not found.</p>;

  return (
    <div style={{ maxWidth: 640 }}>
      <Link to="/">← Back to list</Link>
      <h1 style={{ marginTop: 12 }}>{data.title}</h1>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <PriorityBadge priority={data.priority} />
        <StatusBadge status={data.status} />
      </div>

      <p><strong>Requestor:</strong> {data.requestorEmail}</p>
      <p><strong>Created:</strong> {new Date(data.createdAt).toLocaleString()}</p>
      <p><strong>Updated:</strong> {new Date(data.updatedAt).toLocaleString()}</p>

      <h3>Description</h3>
      <p style={{ whiteSpace: 'pre-wrap' }}>{data.description}</p>

      <h3>Update Status</h3>
      <StatusUpdater
        currentStatus={data.status}
        onUpdate={(s) => mutation.mutate(s)}
        loading={mutation.isPending}
      />
      {mutation.isError && <p style={{ color: 'red' }}>Failed to update status.</p>}
    </div>
  );
}
