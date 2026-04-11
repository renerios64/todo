import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { StatusUpdater } from '../../components/StatusUpdater';

describe('StatusUpdater', () => {
  it('renders the current status as selected', () => {
    render(<StatusUpdater currentStatus="open" onUpdate={vi.fn()} />);
    expect(screen.getByRole('combobox')).toHaveValue('open');
  });

  it('disables Update button when selection matches current status', () => {
    render(<StatusUpdater currentStatus="open" onUpdate={vi.fn()} />);
    expect(screen.getByRole('button', { name: /update/i })).toBeDisabled();
  });

  it('calls onUpdate with new status when changed and submitted', () => {
    const onUpdate = vi.fn();
    render(<StatusUpdater currentStatus="open" onUpdate={onUpdate} />);
    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'resolved' } });
    fireEvent.click(screen.getByRole('button', { name: /update/i }));
    expect(onUpdate).toHaveBeenCalledWith('resolved');
  });
});
