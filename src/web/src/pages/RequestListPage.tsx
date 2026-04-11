import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { getServiceRequests } from '../api/serviceRequests';
import { PriorityBadge, StatusBadge } from '../components/Badges';
import type { Priority, Status } from '../types/serviceRequest';

const PRIORITIES: Priority[] = ['low', 'medium', 'high', 'critical'];
const STATUSES: Status[] = ['open', 'in_progress', 'resolved', 'closed'];

export function RequestListPage() {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [priority, setPriority] = useState('');

  const { data, isLoading, isError } = useQuery({
    queryKey: ['service-requests', search, status, priority],
    queryFn: () =>
      getServiceRequests({
        search: search || undefined,
        status: status || undefined,
        priority: priority || undefined,
      }),
  });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Service Requests</h1>
        <Link to="/new">
          <button>+ New Request</button>
        </Link>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        <input
          placeholder="Search…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ flex: 1, padding: '6px 10px', borderRadius: 4 }}
        />
        <select value={status} onChange={(e) => setStatus(e.target.value)} style={{ padding: '6px 8px', borderRadius: 4 }}>
          <option value="">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s.replace('_', ' ')}</option>
          ))}
        </select>
        <select value={priority} onChange={(e) => setPriority(e.target.value)} style={{ padding: '6px 8px', borderRadius: 4 }}>
          <option value="">All priorities</option>
          {PRIORITIES.map((p) => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>
      </div>

      {isLoading && <p>Loading…</p>}
      {isError && <p style={{ color: 'red' }}>Failed to load requests.</p>}

      {data && data.length === 0 && <p>No requests found.</p>}

      {data && data.length > 0 && (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '2px solid #dee2e6', textAlign: 'left' }}>
              <th style={{ padding: '8px' }}>Title</th>
              <th style={{ padding: '8px' }}>Requestor</th>
              <th style={{ padding: '8px' }}>Priority</th>
              <th style={{ padding: '8px' }}>Status</th>
              <th style={{ padding: '8px' }}>Created</th>
            </tr>
          </thead>
          <tbody>
            {data.map((req) => (
              <tr key={req.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                <td style={{ padding: '8px' }}>
                  <Link to={`/requests/${req.id}`}>{req.title}</Link>
                </td>
                <td style={{ padding: '8px' }}>{req.requestorEmail}</td>
                <td style={{ padding: '8px' }}><PriorityBadge priority={req.priority} /></td>
                <td style={{ padding: '8px' }}><StatusBadge status={req.status} /></td>
                <td style={{ padding: '8px' }}>{new Date(req.createdAt).toLocaleDateString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
