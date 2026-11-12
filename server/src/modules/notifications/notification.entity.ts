import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export enum NotificationType {
  MESSAGE = 'message',
  FRIEND_REQUEST = 'friend_request',
  FRIEND_ACCEPTED = 'friend_accepted',
  ACHIEVEMENT = 'achievement',
  EVENT_INVITE = 'event_invite',
  EVENT_JOINED = 'event_joined',
  EVENT_REMINDER = 'event_reminder',
  MARKETPLACE = 'marketplace',
  NEWS = 'news',
  WEATHER = 'weather',
  SYSTEM = 'system',
}

@Entity('notifications')
@Index('notifications_user_idx', ['userId', 'createdAt'])
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text', nullable: true })
  body: string | null;

  @Column({ type: 'jsonb', nullable: true })
  data: Record<string, unknown> | null;

  @Column({ name: 'is_read', type: 'boolean', default: false })
  isRead: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}