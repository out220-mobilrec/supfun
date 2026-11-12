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
import { Listing } from './listing.entity';

@Entity('listing_reviews')
@Unique(['listingId', 'authorId'])
@Index('listing_reviews_target_idx', ['targetId'])
@Index('listing_reviews_listing_idx', ['listingId'])
export class ListingReview {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'listing_id', type: 'uuid' })
  listingId: string;

  @ManyToOne(() => Listing, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'listing_id' })
  listing: Listing;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @Column({ name: 'target_id', type: 'uuid' })
  targetId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'target_id' })
  target: User;

  @Column({ type: 'int' })
  rating: number;

  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
