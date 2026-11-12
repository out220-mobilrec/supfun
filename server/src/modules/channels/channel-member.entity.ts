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
import { Channel } from './channel.entity';

export enum ChannelRole {
  MEMBER = 'member',
  MODERATOR = 'moderator',
  OWNER = 'owner',
}

@Entity('channel_members')
@Unique(['channelId', 'userId'])
@Index('channel_members_user_idx', ['userId'])
export class ChannelMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'channel_id', type: 'uuid' })
  channelId: string;

  @ManyToOne(() => Channel, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'channel_id' })
  channel: Channel;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: ChannelRole, default: ChannelRole.MEMBER })
  role: ChannelRole;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
