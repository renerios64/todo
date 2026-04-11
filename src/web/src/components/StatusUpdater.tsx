import { useState } from 'react';
import type { Status } from '../types/serviceRequest';

const STATUSES: Status[] = ['open', 'in_progress', 'resolved', 'closed'];

interface Props {
  currentStatus: Status;
  onUpdate: (status: Status) => void;
  loading?: boolean;
}

export function StatusUpdater({ currentStatus, onUpdate, loading }: Props) {
  const [selected, setSelected] = useState<Status>(currentStatus);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (selected !== currentStatus) onUpdate(selected);
  }

  return (
    <form onSubmit={handleSubmit} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      <select
        value={selected}
        onChange={(e) => setSelected(e.target.value as Status)}
        style={{ padding: '4px 8px', borderRadius: 4 }}
      >
        {STATUSES.map((s) => (
          <option key={s} value={s}>
            {s.replace('_', ' ')}
          </option>
        ))}
      </select>
      <button type="submit" disabled={loading || selected === currentStatus}>
        {loading ? 'Saving…' : 'Update'}
      </button>
    </form>
  );
}
