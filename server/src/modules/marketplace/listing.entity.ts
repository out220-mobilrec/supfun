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
import { User } from '../users/user.entity';

export enum ListingStatus {
  DRAFT = 'draft',
  MODERATION = 'moderation',
  ACTIVE = 'active',
  COMPLETED = 'completed',
  SOLD = 'sold',
  REMOVED = 'removed',
}

export const priceTransformer = {
  to: (value: number | null | undefined): number | null =>
    value == null ? null : value,
  from: (value: string | null | undefined): number | null =>
    value == null ? null : Number(value),
};

@Entity('listings')
@Index('listings_seller_idx', ['sellerId'])
@Index('listings_status_idx', ['status'])
export class Listing {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'seller_id', type: 'uuid' })
  sellerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'seller_id' })
  seller: User;

  @Column({ type: 'varchar', length: 32 })
  category: string;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({
    type: 'decimal',
    precision: 12,
    scale: 2,
    nullable: true,
    transformer: priceTransformer,
  })
  price: number | null;

  @Column({ type: 'varchar', length: 8, default: 'RUB' })
  currency: string;

  @Column({ type: 'text', array: true, default: () => 'ARRAY[]::text[]' })
  photos: string[];

  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  city: string | null;

  @Column({ type: 'enum', enum: ListingStatus, default: ListingStatus.ACTIVE })
  status: ListingStatus;

  @Column({ name: 'moderation_comment', type: 'text', nullable: true })
  moderationComment: string | null;

  @Column({ name: 'published_at', type: 'timestamptz', nullable: true })
  publishedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}