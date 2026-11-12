import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

export enum AuthTokenType {
  EMAIL_VERIFY = 'email_verify',
  PASSWORD_RESET = 'password_reset',
  REFRESH = 'refresh',
}

@Entity('auth_tokens')
@Index('auth_tokens_user_idx', ['userId'])
@Index('auth_tokens_hash_idx', ['tokenHash'])
export class AuthToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: AuthTokenType })
  type: AuthTokenType;

  /// SHA-256 hash of the raw token (or code). Never store the plain value.
  @Column({ name: 'token_hash', type: 'varchar', length: 64 })
  tokenHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'used_at', type: 'timestamptz', nullable: true })
  usedAt: Date | null;

  /// Number of failed verification attempts on this code.
  /// When the count exceeds 10 we revoke the whole family
  /// (suspected brute-force).
  @Column({ name: 'attempt_count', type: 'int', default: 0 })
  attemptCount: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
