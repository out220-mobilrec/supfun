import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { WaterBody } from '../waterbodies/waterbody.entity';

export enum UserRole {
  USER = 'user',
  GUIDE = 'guide',
  MODERATOR = 'moderator',
  ADMIN = 'admin',
}

export enum VisibilityScope {
  PUBLIC = 'public',
  FRIENDS = 'friends',
  PRIVATE = 'private',
}

@Entity('users')
@Index(['email'], { unique: true })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  email: string;

  @Column({
    name: 'password_hash',
    type: 'varchar',
    length: 255,
    select: false,
  })
  passwordHash: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({ type: 'varchar', length: 30, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  city: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  region: string | null;

  /**
   * Код страны из справочника `countries` (ISO 3166-1 alpha-2).
   * Значение по умолчанию — Россия; список отдаёт GET /reference/countries.
   */
  @Column({ type: 'varchar', length: 2, nullable: true, default: 'RU' })
  country: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', length: 500, nullable: true })
  avatarUrl: string | null;

  @Column({ type: 'text', nullable: true })
  bio: string | null;

  @Column({ name: 'home_waterbody_id', type: 'uuid', nullable: true })
  homeWaterBodyId: string | null;

  @ManyToOne(() => WaterBody, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'home_waterbody_id' })
  homeWaterBody: WaterBody | null;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role: UserRole;

  @Column({ name: 'is_banned', type: 'boolean', default: false })
  isBanned: boolean;

  @Column({ type: 'int', default: 0 })
  xp: number;

  @Column({ name: 'is_email_verified', type: 'boolean', default: false })
  isEmailVerified: boolean;

  @Column({
    name: 'profile_visibility',
    type: 'enum',
    enum: VisibilityScope,
    default: VisibilityScope.PUBLIC,
  })
  profileVisibility: VisibilityScope;

  @Column({
    name: 'activity_visibility',
    type: 'enum',
    enum: VisibilityScope,
    default: VisibilityScope.PUBLIC,
  })
  activityVisibility: VisibilityScope;

  @Column({
    name: 'geo_visibility',
    type: 'enum',
    enum: VisibilityScope,
    default: VisibilityScope.PRIVATE,
  })
  geoVisibility: VisibilityScope;

  @Column({ name: 'show_online', type: 'boolean', default: true })
  showOnline: boolean;

  /** Язык интерфейса пользователя: ru (по умолчанию) | en. */
  @Column({ type: 'varchar', length: 5, default: 'ru' })
  locale: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}