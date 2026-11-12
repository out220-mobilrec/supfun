import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

/** О чём отзыв. */
export enum ReviewTargetType {
  TRACK = 'track',
  EVENT = 'event',
}

/**
 * Отзыв на маршрут или заплыв, с фотографиями.
 *
 * target_id полиморфный (трек либо заплыв), поэтому внешнего ключа на него нет —
 * существование цели проверяет сервис.
 */
@Entity('reviews')
@Unique('uq_reviews_target_author', ['targetType', 'targetId', 'authorId'])
@Index('reviews_target_idx', ['targetType', 'targetId'])
export class Review {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'target_type', type: 'enum', enum: ReviewTargetType })
  targetType: ReviewTargetType;

  @Column({ name: 'target_id', type: 'uuid' })
  targetId: string;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  /** Оценка 1–5. */
  @Column({ type: 'int' })
  rating: number;

  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @Column({ type: 'text', array: true, default: () => 'ARRAY[]::text[]' })
  photos: string[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
