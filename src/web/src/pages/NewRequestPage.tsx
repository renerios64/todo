import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate, Link } from 'react-router-dom';
import { createServiceRequest } from '../api/serviceRequests';
import type { CreateServiceRequestDto, Priority } from '../types/serviceRequest';

const PRIORITIES: Priority[] = ['low', 'medium', 'high', 'critical'];

const empty: CreateServiceRequestDto = {
  title: '',
  description: '',
  requestorEmail: '',
  priority: 'medium',
};

export function NewRequestPage() {
  const [form, setForm] = useState<CreateServiceRequestDto>(empty);
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const mutation = useMutation({
    mutationFn: createServiceRequest,
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['service-requests'] });
      navigate(`/requests/${created.id}`);
    },
  });

  function handleChange(
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>,
  ) {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    mutation.mutate(form);
  }

  const fieldStyle = {
    display: 'block',
    width: '100%',
    padding: '6px 10px',
    borderRadius: 4,
    border: '1px solid #ced4da',
    marginBottom: 12,
    boxSizing: 'border-box' as const,
  };

  return (
    <div style={{ maxWidth: 560 }}>
      <Link to="/">← Back to list</Link>
      <h1 style={{ marginTop: 12 }}>New Service Request</h1>

      <form onSubmit={handleSubmit}>
        <label htmlFor="title">Title</label>
        <input id="title" name="title" value={form.title} onChange={handleChange} required style={fieldStyle} />

        <label htmlFor="description">Description</label>
        <textarea
          id="description"
          name="description"
          value={form.description}
          onChange={handleChange}
          required
          rows={4}
          style={fieldStyle}
        />

        <label htmlFor="requestorEmail">Requestor Email</label>
        <input
          id="requestorEmail"
          name="requestorEmail"
          type="email"
          value={form.requestorEmail}
          onChange={handleChange}
          required
          style={fieldStyle}
        />

        <label htmlFor="priority">Priority</label>
        <select id="priority" name="priority" value={form.priority} onChange={handleChange} style={fieldStyle}>
          {PRIORITIES.map((p) => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>

        {mutation.isError && <p style={{ color: 'red' }}>Failed to create request.</p>}

        <button type="submit" disabled={mutation.isPending}>
          {mutation.isPending ? 'Submitting…' : 'Submit Request'}
        </button>
      </form>
    </div>
  );
}
