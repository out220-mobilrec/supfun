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

export enum FriendRequestStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
}

@Entity('friend_requests')
@Unique(['requesterId', 'addresseeId'])
@Index('friend_requests_requester_idx', ['requesterId'])
@Index('friend_requests_addressee_idx', ['addresseeId'])
export class FriendRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'requester_id', type: 'uuid' })
  requesterId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'requester_id' })
  requester: User;

  @Column({ name: 'addressee_id', type: 'uuid' })
  addresseeId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'addressee_id' })
  addressee: User;

  @Column({
    type: 'enum',
    enum: FriendRequestStatus,
    default: FriendRequestStatus.PENDING,
  })
  status: FriendRequestStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}