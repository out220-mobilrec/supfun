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

@Entity('user_blocks')
@Unique(['blockerId', 'blockedId'])
@Index('user_blocks_blocker_idx', ['blockerId'])
@Index('user_blocks_blocked_idx', ['blockedId'])
export class UserBlock {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'blocker_id', type: 'uuid' })
  blockerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocker_id' })
  blocker: User;

  @Column({ name: 'blocked_id', type: 'uuid' })
  blockedId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocked_id' })
  blocked: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
