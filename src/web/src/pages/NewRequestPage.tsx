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

  return (
    <div className="page" style={{ maxWidth: 640, margin: '0 auto' }}>
      <Link to="/" className="back-link">← Back to list</Link>
      <h1 className="page-title" style={{ marginBottom: 24 }}>New Service Request</h1>

      <div className="form-card">
        <form onSubmit={handleSubmit}>
          <div className="form-field">
            <label htmlFor="title">Title</label>
            <input
              id="title"
              name="title"
              value={form.title}
              onChange={handleChange}
              required
              placeholder="Brief summary of the request"
            />
          </div>

          <div className="form-field">
            <label htmlFor="description">Description</label>
            <textarea
              id="description"
              name="description"
              value={form.description}
              onChange={handleChange}
              required
              rows={4}
              placeholder="Describe the issue or request in detail…"
            />
          </div>

          <div className="form-field">
            <label htmlFor="requestorEmail">Requestor Email</label>
            <input
              id="requestorEmail"
              name="requestorEmail"
              type="email"
              value={form.requestorEmail}
              onChange={handleChange}
              required
              placeholder="you@example.com"
            />
          </div>

          <div className="form-field">
            <label htmlFor="priority">Priority</label>
            <select
              id="priority"
              name="priority"
              value={form.priority}
              onChange={handleChange}
            >
              {PRIORITIES.map((p) => (
                <option key={p} value={p}>{p}</option>
              ))}
            </select>
          </div>

          {mutation.isError && (
            <p className="text-error" style={{ marginBottom: 16 }}>
              Failed to create request. Please try again.
            </p>
          )}

          <div className="form-actions">
            <button
              type="submit"
              className="btn btn-primary btn-lg"
              disabled={mutation.isPending}
            >
              {mutation.isPending ? 'Submitting…' : 'Submit Request'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
