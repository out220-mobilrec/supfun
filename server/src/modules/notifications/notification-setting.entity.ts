import {
  Column,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';

export enum NotificationCategory {
  EVENTS = 'events',
  MESSAGES = 'messages',
  ACHIEVEMENTS = 'achievements',
  COMMUNITY = 'community',
  NEWS = 'news',
  MARKETPLACE = 'marketplace',
  WEATHER = 'weather',
}

export const NOTIFICATION_CATEGORIES: NotificationCategory[] = [
  NotificationCategory.EVENTS,
  NotificationCategory.MESSAGES,
  NotificationCategory.ACHIEVEMENTS,
  NotificationCategory.COMMUNITY,
  NotificationCategory.NEWS,
  NotificationCategory.MARKETPLACE,
  NotificationCategory.WEATHER,
];

@Entity('notification_settings')
@Unique(['userId', 'category'])
@Index('notification_settings_user_idx', ['userId'])
export class NotificationSetting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'enum', enum: NotificationCategory })
  category: NotificationCategory;

  @Column({ name: 'in_app', type: 'boolean', default: true })
  inApp: boolean;

  @Column({ type: 'boolean', default: true })
  push: boolean;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
