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
import { Conversation } from './conversation.entity';
import { User } from '../users/user.entity';

@Entity('conversation_participants')
@Unique(['conversationId', 'userId'])
@Index('conversation_participants_user_idx', ['userId'])
export class ConversationParticipant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @ManyToOne(() => Conversation, (conversation) => conversation.participants, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'conversation_id' })
  conversation: Conversation;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'last_read_at', type: 'timestamptz', nullable: true })
  lastReadAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}