import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Listing } from './listing.entity';

export enum ListingLeadStatus {
  NEW = 'new',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  CLOSED = 'closed',
}

@Entity('listing_leads')
@Index('listing_leads_listing_idx', ['listingId'])
@Index('listing_leads_buyer_idx', ['buyerId'])
export class ListingLead {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'listing_id', type: 'uuid' })
  listingId: string;

  @ManyToOne(() => Listing, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'listing_id' })
  listing: Listing;

  @Column({ name: 'buyer_id', type: 'uuid' })
  buyerId: string;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  @Column({ type: 'enum', enum: ListingLeadStatus, default: ListingLeadStatus.NEW })
  status: ListingLeadStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}