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
import { Event } from './event.entity';
import { User } from '../users/user.entity';

export enum ParticipantStatus {
  GOING = 'going',
  MAYBE = 'maybe',
  NOT_GOING = 'not_going',
}

@Entity('event_participants')
@Unique(['eventId', 'userId'])
@Index('event_participants_event_idx', ['eventId'])
@Index('event_participants_user_idx', ['userId'])
export class EventParticipant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'event_id', type: 'uuid' })
  eventId: string;

  @ManyToOne(() => Event, (event) => event.participants, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'event_id' })
  event: Event;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: ParticipantStatus, default: ParticipantStatus.GOING })
  status: ParticipantStatus;

  @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
  joinedAt: Date;
}