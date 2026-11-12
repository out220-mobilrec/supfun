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
import { User, VisibilityScope } from '../users/user.entity';

export enum PostType {
  SWIM = 'swim',
  ROUTE = 'route',
  ACHIEVEMENT = 'achievement',
  EVENT = 'event',
  NEWS = 'news',
  WATERBODY = 'waterbody',
}

@Entity('posts')
@Index('posts_author_idx', ['authorId'])
@Index('posts_type_idx', ['type'])
@Index('posts_created_idx', ['createdAt'])
export class Post {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @Column({ type: 'enum', enum: PostType, default: PostType.SWIM })
  type: PostType;

  @Column({ type: 'varchar', length: 200, nullable: true })
  title: string | null;

  @Column({ type: 'text', nullable: true })
  body: string | null;

  @Column({ type: 'text', array: true, default: () => 'ARRAY[]::text[]' })
  photos: string[];

  @Column({ name: 'ref_id', type: 'uuid', nullable: true })
  refId: string | null;

  @Column({ name: 'ref_type', type: 'varchar', length: 40, nullable: true })
  refType: string | null;

  @Column({
    type: 'enum',
    enum: VisibilityScope,
    default: VisibilityScope.PUBLIC,
  })
  visibility: VisibilityScope;

  @Column({ name: 'like_count', type: 'int', default: 0 })
  likeCount: number;

  @Column({ name: 'comment_count', type: 'int', default: 0 })
  commentCount: number;

  @Column({ name: 'share_count', type: 'int', default: 0 })
  shareCount: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
