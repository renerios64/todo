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
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Service Requests</h1>
        <Link to="/new" className="btn btn-primary">
          + New Request
        </Link>
      </div>

      <div className="filter-bar">
        <input
          placeholder="Search…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s.replace('_', ' ')}</option>
          ))}
        </select>
        <select value={priority} onChange={(e) => setPriority(e.target.value)}>
          <option value="">All priorities</option>
          {PRIORITIES.map((p) => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>
      </div>

      {isLoading && <p className="text-muted">Loading…</p>}
      {isError && <p className="text-error">Failed to load requests.</p>}
      {data && data.length === 0 && <p className="text-muted">No requests found.</p>}

      {data && data.length > 0 && (
        <table className="data-table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Requestor</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {data.map((req) => (
              <tr key={req.id}>
                <td>
                  <Link to={`/requests/${req.id}`}>{req.title}</Link>
                </td>
                <td>{req.requestorEmail}</td>
                <td><PriorityBadge priority={req.priority} /></td>
                <td><StatusBadge status={req.status} /></td>
                <td>{new Date(req.createdAt).toLocaleDateString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
