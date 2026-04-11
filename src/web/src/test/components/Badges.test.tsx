import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PriorityBadge, StatusBadge } from '../../components/Badges';

describe('PriorityBadge', () => {
  it.each(['low', 'medium', 'high', 'critical'] as const)('renders %s priority', (p) => {
    render(<PriorityBadge priority={p} />);
    expect(screen.getByText(p)).toBeInTheDocument();
  });
});

describe('StatusBadge', () => {
  it('renders in_progress with a space', () => {
    render(<StatusBadge status="in_progress" />);
    expect(screen.getByText('in progress')).toBeInTheDocument();
  });
});
