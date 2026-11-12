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
import { Channel } from './channel.entity';

@Entity('channel_posts')
@Index('channel_posts_channel_idx', ['channelId', 'createdAt'])
export class ChannelPost {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'channel_id', type: 'uuid' })
  channelId: string;

  @ManyToOne(() => Channel, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'channel_id' })
  channel: Channel;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @Column({ type: 'varchar', length: 200, nullable: true })
  title: string | null;

  @Column({ type: 'text', nullable: true })
  body: string | null;

  @Column({ type: 'text', array: true, default: () => 'ARRAY[]::text[]' })
  photos: string[];

  @Column({ name: 'is_pinned', type: 'boolean', default: false })
  isPinned: boolean;

  @Column({ name: 'like_count', type: 'int', default: 0 })
  likeCount: number;

  @Column({ name: 'comment_count', type: 'int', default: 0 })
  commentCount: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
