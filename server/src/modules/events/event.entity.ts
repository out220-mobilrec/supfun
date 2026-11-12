import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import type { Track } from '../tracks/track.entity';
import { EventParticipant } from './event-participant.entity';

export enum EventStatus {
  DRAFT = 'draft',
  SCHEDULED = 'scheduled',
  ON_WATER = 'on_water',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum EventVisibility {
  PRIVATE = 'private',
  FRIENDS = 'friends',
  PUBLIC = 'public',
}

export enum EventAccess {
  OPEN = 'open',
  INVITE = 'invite',
}

export enum EventLevel {
  BEGINNER = 'beginner',
  MEDIUM = 'medium',
  PRO = 'pro',
}

@Entity('events')
@Index('events_date_idx', ['eventDate'])
export class Event {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organizer_id', type: 'uuid' })
  organizerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organizer_id' })
  organizer: User;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'text', array: true, default: () => 'ARRAY[]::text[]' })
  photos: string[];

  @Column({ name: 'waterbody_id', type: 'uuid', nullable: true })
  waterBodyId: string | null;

  @ManyToOne(() => WaterBody, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'waterbody_id' })
  waterBody: WaterBody | null;

  /**
   * Маршрут, по которому проводится заплыв. Если он задан, водоём,
   * ожидаемая длительность и дистанция берутся из маршрута.
   * Связь по имени сущности: tracks/event.entity импортируют друг друга.
   */
  @Column({ name: 'track_id', type: 'uuid', nullable: true })
  trackId: string | null;

  @ManyToOne('Track', { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'track_id' })
  track: Track | null;

  @Column({ name: 'event_date', type: 'timestamptz' })
  eventDate: Date;

  @Column({ name: 'expected_duration_minutes', type: 'int', nullable: true })
  expectedDurationMinutes: number | null;

  @Column({ name: 'expected_distance_meters', type: 'int', nullable: true })
  expectedDistanceMeters: number | null;

  @Column({ type: 'enum', enum: EventLevel, default: EventLevel.BEGINNER })
  level: EventLevel;

  @Column({ type: 'enum', enum: EventVisibility, default: EventVisibility.PUBLIC })
  visibility: EventVisibility;

  @Column({ type: 'enum', enum: EventAccess, default: EventAccess.OPEN })
  access: EventAccess;

  @Column({ name: 'max_participants', type: 'int', nullable: true })
  maxParticipants: number | null;

  @Column({
    type: 'enum',
    enum: EventStatus,
    default: EventStatus.SCHEDULED,
  })
  status: EventStatus;

  @Column({
    name: 'start_point',
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  startPoint: unknown;

  @Column({ name: 'start_lat', type: 'double precision', nullable: true })
  startLat: number | null;

  @Column({ name: 'start_lng', type: 'double precision', nullable: true })
  startLng: number | null;

  @OneToMany(() => EventParticipant, (participant) => participant.event, {
    cascade: true,
  })
  participants: EventParticipant[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}