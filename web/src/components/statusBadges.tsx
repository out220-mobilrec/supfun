import { Badge, type Tone } from './ui';
import type {
  EventLevel,
  EventStatus,
  ListingLeadStatus,
  ListingStatus,
  ParticipantStatus,
  TrackDifficulty,
  TrackStatus,
  UserRole,
} from '../lib/lists';
import {
  eventLevelLabel,
  eventStatusLabel,
  leadStatusLabel,
  listingStatusLabel,
  participantStatusLabel,
  roleLabel,
  trackDifficultyLabel,
  trackStatusLabel,
} from '../lib/labels';

function badge(tone: Tone, label: string) {
  return <Badge tone={tone}>{label}</Badge>;
}

export function RoleBadge({ role }: { role: UserRole }) {
  switch (role) {
    case 'admin':
      return badge('violet', roleLabel(role));
    case 'moderator':
      return badge('blue', roleLabel(role));
    case 'guide':
      return badge('cyan', roleLabel(role));
    default:
      return badge('slate', roleLabel(role));
  }
}

export function EventStatusBadge({ status }: { status: EventStatus }) {
  switch (status) {
    case 'scheduled':
      return badge('green', eventStatusLabel(status));
    case 'on_water':
      return badge('blue', eventStatusLabel(status));
    case 'completed':
      return badge('slate', eventStatusLabel(status));
    case 'cancelled':
      return badge('red', eventStatusLabel(status));
    default:
      return badge('slate', eventStatusLabel(status));
  }
}

export function EventLevelBadge({ level }: { level: EventLevel }) {
  const tones: Record<EventLevel, Tone> = { beginner: 'green', medium: 'amber', pro: 'red' };
  return badge(tones[level], eventLevelLabel(level));
}

export function ParticipantStatusBadge({ status }: { status: ParticipantStatus }) {
  const tones: Record<ParticipantStatus, Tone> = {
    going: 'green',
    maybe: 'amber',
    not_going: 'slate',
  };
  return badge(tones[status], participantStatusLabel(status));
}

export function TrackStatusBadge({ status }: { status: TrackStatus }) {
  switch (status) {
    case 'published':
      return badge('green', trackStatusLabel(status));
    case 'hidden':
      return badge('red', trackStatusLabel(status));
    case 'moderation':
      return badge('amber', trackStatusLabel(status));
    default:
      return badge('slate', trackStatusLabel(status));
  }
}

export function TrackDifficultyBadge({ difficulty }: { difficulty: TrackDifficulty | null }) {
  if (!difficulty) return badge('slate', '—');
  const tones: Record<TrackDifficulty, Tone> = { easy: 'green', medium: 'amber', hard: 'red' };
  return badge(tones[difficulty], trackDifficultyLabel(difficulty));
}

export function ListingStatusBadge({ status }: { status: ListingStatus }) {
  const tones: Record<ListingStatus, Tone> = {
    draft: 'slate',
    moderation: 'amber',
    active: 'green',
    completed: 'blue',
    sold: 'violet',
    removed: 'slate',
  };
  return badge(tones[status], listingStatusLabel(status));
}

export function LeadStatusBadge({ status }: { status: ListingLeadStatus }) {
  switch (status) {
    case 'new':
      return badge('amber', leadStatusLabel(status));
    case 'accepted':
      return badge('green', leadStatusLabel(status));
    case 'rejected':
      return badge('red', leadStatusLabel(status));
    default:
      return badge('slate', leadStatusLabel(status));
  }
}

export function BannedBadge({ banned }: { banned?: boolean }) {
  if (!banned) return null;
  return badge('red', 'Забанен');
}