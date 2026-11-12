import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from '../users/user.entity';
import { Event } from './event.entity';

export enum EventInviteStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
}

@Entity('event_invites')
@Unique(['eventId', 'inviteeId'])
@Index('event_invites_invitee_idx', ['inviteeId'])
export class EventInvite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @ManyToOne(() => Event, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @Column({ name: 'inviter_id', type: 'uuid' })
  inviterId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'inviter_id' })
  inviter: User;

  @Column({ name: 'invitee_id', type: 'uuid' })
  inviteeId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'invitee_id' })
  invitee: User;

  @Column({
    type: 'enum',
    enum: EventInviteStatus,
    default: EventInviteStatus.PENDING,
  })
  status: EventInviteStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
