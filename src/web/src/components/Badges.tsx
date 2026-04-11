import type { Priority, Status } from '../types/serviceRequest';

const priorityColors: Record<Priority, string> = {
  low: '#6c757d',
  medium: '#0d6efd',
  high: '#fd7e14',
  critical: '#dc3545',
};

const statusColors: Record<Status, string> = {
  open: '#198754',
  in_progress: '#0dcaf0',
  resolved: '#6c757d',
  closed: '#343a40',
};

interface BadgeProps {
  value: string;
  colorMap: Record<string, string>;
  'data-testid'?: string;
}

function Badge({ value, colorMap, 'data-testid': testId }: BadgeProps) {
  const color = colorMap[value] ?? '#adb5bd';
  return (
    <span
      data-testid={testId}
      style={{
        backgroundColor: color,
        color: '#fff',
        padding: '2px 10px',
        borderRadius: 12,
        fontSize: 12,
        fontWeight: 600,
        textTransform: 'capitalize',
      }}
    >
      {value.replace('_', ' ')}
    </span>
  );
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  return <Badge value={priority} colorMap={priorityColors} />;
}

export function StatusBadge({ status }: { status: Status }) {
  return <Badge value={status} colorMap={statusColors} data-testid="status-badge" />;
}
