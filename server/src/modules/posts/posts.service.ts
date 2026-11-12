import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { OnEvent } from '@nestjs/event-emitter';
import { In, Repository } from 'typeorm';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { UserRole, VisibilityScope } from '../users/user.entity';
import { BlocksService } from '../blocks/blocks.service';
import { FriendsService } from '../friends/friends.service';
import { Post, PostType } from './post.entity';
import { PostLike } from './post-like.entity';
import { PostComment } from './post-comment.entity';

const NO_MATCH = '00000000-0000-0000-0000-000000000000';

export interface PostView extends Post {
  likedByMe: boolean;
  canDelete: boolean;
}

export interface PostListResult {
  items: PostView[];
  hasMore: boolean;
}

export interface PostFilters {
  limit?: number;
  offset?: number;
  authorId?: string;
  type?: PostType;
}

@Injectable()
export class PostsService {
  constructor(
    @InjectRepository(Post)
    private readonly posts: Repository<Post>,
    @InjectRepository(PostLike)
    private readonly likes: Repository<PostLike>,
    @InjectRepository(PostComment)
    private readonly comments: Repository<PostComment>,
    private readonly blocks: BlocksService,
    private readonly friends: FriendsService,
  ) {}

  async create(
    authorId: string,
    data: Partial<Post>,
  ): Promise<PostView> {
    const post = this.posts.create({
      authorId,
      type: data.type ?? PostType.SWIM,
      title: data.title ?? null,
      body: data.body ?? null,
      photos: data.photos ?? [],
      refId: data.refId ?? null,
      refType: data.refType ?? null,
      visibility: data.visibility ?? VisibilityScope.PUBLIC,
    });
    const saved = await this.posts.save(post);
    return this.decorate(saved, {
      id: authorId,
      role: UserRole.USER,
    } as AuthUser);
  }

  async list(
    viewer: AuthUser,
    filters: PostFilters = {},
  ): Promise<PostListResult> {
    const limit = Math.min(Math.max(filters.limit ?? 10, 1), 50);
    const offset = Math.max(filters.offset ?? 0, 0);
    const friendIds = await this.friends.friendIds(viewer.id);
    const hidden = await this.blocks.hiddenIds(viewer.id);
    const friendScope = friendIds.length ? friendIds : [NO_MATCH];

    const qb = this.posts
      .createQueryBuilder('post')
      .leftJoinAndSelect('post.author', 'author')
      .where(
        `(post.authorId = :viewer OR post.visibility = :public OR (post.visibility = :friends AND post.authorId IN (:...friendScope)))`,
        {
          viewer: viewer.id,
          public: VisibilityScope.PUBLIC,
          friends: VisibilityScope.FRIENDS,
          friendScope,
        },
      )
      .orderBy('post.createdAt', 'DESC')
      .take(limit + 1)
      .skip(offset);

    if (hidden.length) {
      qb.andWhere('post.authorId NOT IN (:...hidden)', { hidden });
    }
    if (filters.authorId) {
      qb.andWhere('post.authorId = :authorId', { authorId: filters.authorId });
    }
    if (filters.type) {
      qb.andWhere('post.type = :type', { type: filters.type });
    }

    const rows = await qb.getMany();
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const items = await this.decorateMany(page, viewer);
    return { items, hasMore };
  }

  async get(id: string, viewer: AuthUser): Promise<PostView> {
    const post = await this.posts.findOne({
      where: { id },
      relations: { author: true },
    });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    const allowed = await this.canView(post, viewer);
    if (!allowed) {
      throw new NotFoundException('Post not found');
    }
    return this.decorate(post, viewer);
  }

  async remove(id: string, viewer: AuthUser): Promise<{ ok: boolean }> {
    const post = await this.posts.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    const staff =
      viewer.role === UserRole.ADMIN || viewer.role === UserRole.MODERATOR;
    if (post.authorId !== viewer.id && !staff) {
      throw new ForbiddenException('Not your post');
    }
    await this.posts.remove(post);
    return { ok: true };
  }

  async toggleLike(
    id: string,
    viewer: AuthUser,
  ): Promise<{ liked: boolean; likeCount: number }> {
    const post = await this.posts.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    await this.assertViewable(post, viewer);
    const existing = await this.likes.findOne({
      where: { postId: id, userId: viewer.id },
    });
    if (existing) {
      await this.likes.remove(existing);
      await this.posts.decrement({ id }, 'likeCount', 1);
      post.likeCount = Math.max(0, post.likeCount - 1);
      return { liked: false, likeCount: post.likeCount };
    }
    await this.likes.save(this.likes.create({ postId: id, userId: viewer.id }));
    await this.posts.increment({ id }, 'likeCount', 1);
    return { liked: true, likeCount: post.likeCount + 1 };
  }

  async share(id: string, viewer: AuthUser): Promise<{ shareCount: number }> {
    const post = await this.posts.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    await this.assertViewable(post, viewer);
    await this.posts.increment({ id }, 'shareCount', 1);
    return { shareCount: post.shareCount + 1 };
  }

  async listComments(id: string, viewer: AuthUser): Promise<PostComment[]> {
    const post = await this.posts.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    await this.assertViewable(post, viewer);
    return this.comments.find({
      where: { postId: id },
      relations: { author: true },
      order: { createdAt: 'ASC' },
    });
  }

  async addComment(
    id: string,
    viewer: AuthUser,
    body: string,
  ): Promise<PostComment> {
    const post = await this.posts.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    await this.assertViewable(post, viewer);
    const comment = await this.comments.save(
      this.comments.create({ postId: id, authorId: viewer.id, body }),
    );
    await this.posts.increment({ id }, 'commentCount', 1);
    return this.comments.findOne({
      where: { id: comment.id },
      relations: { author: true },
    }) as Promise<PostComment>;
  }

  async removeComment(
    postId: string,
    commentId: string,
    viewer: AuthUser,
  ): Promise<{ ok: boolean }> {
    const comment = await this.comments.findOne({ where: { id: commentId } });
    if (!comment || comment.postId !== postId) {
      throw new NotFoundException('Comment not found');
    }
    const post = await this.posts.findOne({ where: { id: postId } });
    const staff =
      viewer.role === UserRole.ADMIN || viewer.role === UserRole.MODERATOR;
    const allowed =
      comment.authorId === viewer.id ||
      post?.authorId === viewer.id ||
      staff;
    if (!allowed) {
      throw new ForbiddenException('Not allowed to delete this comment');
    }
    await this.comments.remove(comment);
    await this.posts.decrement({ id: postId }, 'commentCount', 1);
    return { ok: true };
  }

  @OnEvent('achievements.unlocked')
  async onAchievements(payload: {
    userId: string;
    achievements: { code: string; title?: string }[];
  }): Promise<void> {
    if (!payload?.userId || !payload.achievements?.length) return;
    const titles = payload.achievements
      .map((a) => a.title ?? a.code)
      .join(', ');
    await this.create(payload.userId, {
      type: PostType.ACHIEVEMENT,
      title: 'Новое достижение',
      body: titles,
    });
  }

  @OnEvent('events.created')
  async onEventCreated(payload: {
    organizerId: string;
    eventId: string;
    title: string;
  }): Promise<void> {
    if (!payload?.organizerId) return;
    await this.create(payload.organizerId, {
      type: PostType.EVENT,
      title: 'Новый заплыв',
      body: payload.title,
      refId: payload.eventId,
      refType: 'event',
    });
  }

  @OnEvent('tracks.completed')
  async onTrackCompleted(payload: {
    userId: string;
    trackId: string;
    name: string;
    distanceMeters: number;
  }): Promise<void> {
    if (!payload?.userId) return;
    const km = (payload.distanceMeters ?? 0) / 1000;
    await this.create(payload.userId, {
      type: PostType.SWIM,
      title: payload.name,
      body: km > 0 ? `Дистанция: ${km.toFixed(2)} км` : undefined,
      refId: payload.trackId,
      refType: 'track',
    });
  }

  private async canView(post: Post, viewer: AuthUser): Promise<boolean> {
    if (post.authorId === viewer.id) return true;
    if (
      viewer.role === UserRole.ADMIN ||
      viewer.role === UserRole.MODERATOR
    ) {
      return true;
    }
    if (await this.blocks.blockedEither(viewer.id, post.authorId)) {
      return false;
    }
    if (post.visibility === VisibilityScope.PUBLIC) return true;
    if (post.visibility === VisibilityScope.FRIENDS) {
      return this.friends.areFriends(viewer.id, post.authorId);
    }
    return false;
  }

  private async assertViewable(post: Post, viewer: AuthUser): Promise<void> {
    if (!(await this.canView(post, viewer))) {
      throw new NotFoundException('Post not found');
    }
  }

  private async decorate(post: Post, viewer: AuthUser): Promise<PostView> {
    const [view] = await this.decorateMany([post], viewer);
    return view;
  }

  private async decorateMany(
    posts: Post[],
    viewer: AuthUser,
  ): Promise<PostView[]> {
    if (posts.length === 0) return [];
    const ids = posts.map((p) => p.id);
    const liked = await this.likes.find({
      where: { postId: In(ids), userId: viewer.id },
      select: { postId: true },
    });
    const likedSet = new Set(liked.map((l) => l.postId));
    const staff =
      viewer.role === UserRole.ADMIN || viewer.role === UserRole.MODERATOR;
    return posts.map((p) => {
      const view = Object.assign(p, {
        likedByMe: likedSet.has(p.id),
        canDelete: p.authorId === viewer.id || staff,
      }) as PostView;
      return view;
    });
  }
}
