import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ConversationParticipant } from './conversation-participant.entity';

export enum ConversationType {
  DIRECT = 'direct',
  GROUP = 'group',
  EVENT = 'event',
  DEAL = 'deal',
}

@Entity('conversations')
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    type: 'enum',
    enum: ConversationType,
    default: ConversationType.DIRECT,
  })
  type: ConversationType;

  @Column({ type: 'varchar', length: 200, nullable: true })
  title: string | null;

  @Column({ name: 'event_id', type: 'uuid', nullable: true })
  eventId: string | null;

  @Column({ name: 'last_message_at', type: 'timestamptz', nullable: true })
  lastMessageAt: Date | null;

  @OneToMany(() => ConversationParticipant, (participant) => participant.conversation, {
    cascade: true,
  })
  participants: ConversationParticipant[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}