import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Conversation } from './conversation.entity';
import { User } from '../users/user.entity';

export enum MessageType {
  TEXT = 'text',
  PHOTO = 'photo',
  LOCATION = 'location',
}

export enum MessageStatus {
  SENT = 'sent',
  DELIVERED = 'delivered',
  READ = 'read',
  ERROR = 'error',
  DELETED = 'deleted',
}

@Entity('messages')
@Index('messages_conversation_idx', ['conversationId'])
export class Message {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversation_id' })
  conversation: Conversation;

  @Column({ name: 'sender_id', type: 'uuid' })
  senderId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'sender_id' })
  sender: User;

  @Column({ type: 'enum', enum: MessageType, default: MessageType.TEXT })
  type: MessageType;

  @Column({ type: 'text', nullable: true })
  content: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  nonce: string | null;

  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @Column({ name: 'reply_to_id', type: 'uuid', nullable: true })
  replyToId: string | null;

  @ManyToOne(() => Message, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'reply_to_id' })
  replyTo: Message | null;

  @Column({ type: 'enum', enum: MessageStatus, default: MessageStatus.SENT })
  status: MessageStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}