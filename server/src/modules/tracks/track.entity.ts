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
import { Event } from '../events/event.entity';
import { Route } from '../routes/route.entity';
import { TrackPoint } from './track-point.entity';

export enum TrackStatus {
  DRAFT = 'draft',
  PRIVATE = 'private',
  MODERATION = 'moderation',
  PUBLISHED = 'published',
  HIDDEN = 'hidden',
}

export enum TrackDifficulty {
  EASY = 'easy',
  MEDIUM = 'medium',
  HARD = 'hard',
}

@Entity('tracks')
@Index('tracks_user_idx', ['userId'])
export class Track {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar', length: 200, nullable: true })
  name: string | null;

  @Column({
    type: 'enum',
    enum: TrackStatus,
    default: TrackStatus.PRIVATE,
  })
  status: TrackStatus;

  @Column({
    type: 'enum',
    enum: TrackDifficulty,
    nullable: true,
  })
  difficulty: TrackDifficulty | null;

  @Column({ name: 'waterbody_id', type: 'uuid', nullable: true })
  waterBodyId: string | null;

  @ManyToOne(() => WaterBody, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'waterbody_id' })
  waterBody: WaterBody | null;

  @Column({ name: 'event_id', type: 'uuid', nullable: true })
  eventId: string | null;

  @ManyToOne(() => Event, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'event_id' })
  event: Event | null;

  /** Маршрут справочника, по которому шёл заплыв. */
  @Column({ name: 'route_id', type: 'uuid', nullable: true })
  routeId: string | null;

  @ManyToOne(() => Route, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'route_id' })
  route: Route | null;

  @Column({ name: 'distance_meters', type: 'double precision', default: 0 })
  distanceMeters: number;

  @Column({ name: 'duration_seconds', type: 'int', default: 0 })
  durationSeconds: number;

  @Column({ name: 'avg_speed_kph', type: 'double precision', default: 0 })
  avgSpeedKph: number;

  @Column({ name: 'max_speed_kph', type: 'double precision', default: 0 })
  maxSpeedKph: number;

  @Column({ name: 'elevation_gain_m', type: 'double precision', default: 0 })
  elevationGainMeters: number;

  @Column({ name: 'elevation_loss_m', type: 'double precision', default: 0 })
  elevationLossMeters: number;

  @Column({ type: 'int', default: 0 })
  calories: number;

  @Column({ name: 'started_at', type: 'timestamptz' })
  startedAt: Date;

  @Column({ name: 'ended_at', type: 'timestamptz', nullable: true })
  endedAt: Date | null;

  @Column({
    name: 'route_line',
    type: 'geometry',
    spatialFeatureType: 'LineString',
    srid: 4326,
    nullable: true,
  })
  routeLine: unknown;

  @OneToMany(() => TrackPoint, (point) => point.track, { cascade: true })
  points: TrackPoint[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}