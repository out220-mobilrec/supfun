import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../users/user.entity';
import { Channel } from './channel.entity';
import { ChannelMember, ChannelRole } from './channel-member.entity';
import { ChannelPost } from './channel-post.entity';
import { ChannelPostLike } from './channel-post-like.entity';
import { ChannelPostComment } from './channel-post-comment.entity';
import { CreateChannelDto } from './dto/create-channel.dto';
import { UpdateChannelDto } from './dto/update-channel.dto';
import { CreateChannelPostDto } from './dto/create-channel-post.dto';

export interface ChannelView extends Channel {
  subscriberCount: number;
  isMember: boolean;
  myRole: ChannelRole | null;
}

export interface ChannelPostView extends ChannelPost {
  likedByMe: boolean;
  canDelete: boolean;
  canPin: boolean;
}

export interface Paginated<T> {
  items: T[];
  hasMore: boolean;
}

@Injectable()
export class ChannelsService {
  constructor(
    @InjectRepository(Channel)
    private readonly channels: Repository<Channel>,
    @InjectRepository(ChannelMember)
    private readonly members: Repository<ChannelMember>,
    @InjectRepository(ChannelPost)
    private readonly posts: Repository<ChannelPost>,
    @InjectRepository(ChannelPostLike)
    private readonly likes: Repository<ChannelPostLike>,
    @InjectRepository(ChannelPostComment)
    private readonly comments: Repository<ChannelPostComment>,
  ) {}

  async list(
    me: AuthUser,
    options: { q?: string; limit?: number; offset?: number } = {},
  ): Promise<ChannelView[]> {
    const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);
    const offset = Math.max(options.offset ?? 0, 0);
    const qb = this.channels
      .createQueryBuilder('channel')
      .leftJoinAndSelect('channel.owner', 'owner')
      .orderBy('channel.createdAt', 'DESC')
      .take(limit)
      .skip(offset);

    if (options.q?.trim()) {
      qb.andWhere('(channel.name ILIKE :like OR channel.description ILIKE :like)', {
        like: `%${options.q.trim()}%`,
      });
    }
    if (!this.isStaff(me)) {
      qb.andWhere(
        `(channel.isPublic = true OR EXISTS (
           SELECT 1 FROM channel_members m
           WHERE m.channel_id = channel.id AND m.user_id = :me
         ))`,
        { me: me.id },
      );
    }
    const rows = await qb.getMany();
    return this.decorateChannels(rows, me.id);
  }

  async get(id: string, me: AuthUser): Promise<ChannelView> {
    const channel = await this.channels.findOne({
      where: { id },
      relations: { owner: true },
    });
    if (!channel) {
      throw new NotFoundException('Channel not found');
    }
    await this.assertAccess(channel.id, me);
    const [view] = await this.decorateChannels([channel], me.id);
    return view;
  }

  async create(me: AuthUser, dto: CreateChannelDto): Promise<ChannelView> {
    const slug = await this.uniqueSlug(dto.name);
    const channel = await this.channels.save(
      this.channels.create({
        name: dto.name,
        slug,
        description: dto.description ?? null,
        photoUrl: dto.photoUrl ?? null,
        ownerId: me.id,
        isPublic: dto.isPublic ?? true,
      }),
    );
    await this.members.save(
      this.members.create({
        channelId: channel.id,
        userId: me.id,
        role: ChannelRole.OWNER,
      }),
    );
    return this.get(channel.id, me);
  }

  async update(
    id: string,
    me: AuthUser,
    dto: UpdateChannelDto,
  ): Promise<ChannelView> {
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    if (!this.canManage(channel, membership, me)) {
      throw new ForbiddenException('Not allowed to edit this channel');
    }
    if (dto.name !== undefined) channel.name = dto.name;
    if (dto.description !== undefined) channel.description = dto.description;
    if (dto.photoUrl !== undefined) channel.photoUrl = dto.photoUrl;
    if (dto.isPublic !== undefined) channel.isPublic = dto.isPublic;
    await this.channels.save(channel);
    return this.get(id, me);
  }

  async remove(id: string, me: AuthUser): Promise<{ ok: boolean }> {
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    if (channel.ownerId !== me.id && !this.isStaff(me)) {
      throw new ForbiddenException('Not allowed to delete this channel');
    }
    void membership;
    await this.channels.remove(channel);
    return { ok: true };
  }

  async join(id: string, me: AuthUser): Promise<ChannelView> {
    const channel = await this.requireChannel(id);
    const existing = await this.membership(id, me.id);
    if (!existing) {
      if (!channel.isPublic && channel.ownerId !== me.id) {
        throw new ForbiddenException('Channel is private');
      }
      await this.members.save(
        this.members.create({
          channelId: id,
          userId: me.id,
          role: ChannelRole.MEMBER,
        }),
      );
    }
    return this.get(id, me);
  }

  async leave(id: string, me: AuthUser): Promise<{ ok: boolean }> {
    const channel = await this.requireChannel(id);
    if (channel.ownerId === me.id) {
      throw new ForbiddenException('Owner cannot leave the channel');
    }
    const existing = await this.membership(id, me.id);
    if (existing) {
      await this.members.remove(existing);
    }
    return { ok: true };
  }

  async listMembers(id: string, me: AuthUser): Promise<ChannelMember[]> {
    await this.get(id, me);
    return this.members.find({
      where: { channelId: id },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });
  }

  async setMemberRole(
    id: string,
    me: AuthUser,
    userId: string,
    role: ChannelRole,
  ): Promise<ChannelMember> {
    const channel = await this.requireChannel(id);
    if (channel.ownerId !== me.id) {
      throw new ForbiddenException('Only the owner can change roles');
    }
    if (userId === channel.ownerId) {
      throw new ForbiddenException('Cannot change the owner role');
    }
    const membership = await this.membership(id, userId);
    if (!membership) {
      throw new NotFoundException('Member not found');
    }
    membership.role = role;
    return this.members.save(membership);
  }

  async listPosts(
    id: string,
    me: AuthUser,
    options: { limit?: number; offset?: number } = {},
  ): Promise<Paginated<ChannelPostView>> {
    await this.get(id, me);
    const limit = Math.min(Math.max(options.limit ?? 10, 1), 50);
    const offset = Math.max(options.offset ?? 0, 0);
    const rows = await this.posts.find({
      where: { channelId: id },
      relations: { author: true },
      order: { isPinned: 'DESC', createdAt: 'DESC' },
      take: limit + 1,
      skip: offset,
    });
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const items = await this.decoratePosts(page, id, me);
    return { items, hasMore };
  }

  async createPost(
    id: string,
    me: AuthUser,
    dto: CreateChannelPostDto,
  ): Promise<ChannelPostView> {
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    if (!membership && !this.isStaff(me) && channel.ownerId !== me.id) {
      throw new ForbiddenException('Join the channel to post');
    }
    if (!dto.body?.trim() && !dto.title?.trim() && !(dto.photos?.length)) {
      throw new ForbiddenException('Post is empty');
    }
    const post = await this.posts.save(
      this.posts.create({
        channelId: id,
        authorId: me.id,
        title: dto.title ?? null,
        body: dto.body ?? null,
        photos: dto.photos ?? [],
      }),
    );
    const saved = await this.posts.findOne({
      where: { id: post.id },
      relations: { author: true },
    });
    const [view] = await this.decoratePosts(saved ? [saved] : [], id, me);
    return view;
  }

  async deletePost(
    id: string,
    postId: string,
    me: AuthUser,
  ): Promise<{ ok: boolean }> {
    const post = await this.requirePost(id, postId);
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    const canDelete =
      post.authorId === me.id ||
      this.canManage(channel, membership, me);
    if (!canDelete) {
      throw new ForbiddenException('Not allowed to delete this post');
    }
    await this.posts.remove(post);
    return { ok: true };
  }

  async togglePin(
    id: string,
    postId: string,
    me: AuthUser,
  ): Promise<ChannelPostView> {
    const post = await this.requirePost(id, postId);
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    if (!this.canManage(channel, membership, me)) {
      throw new ForbiddenException('Not allowed to pin posts');
    }
    post.isPinned = !post.isPinned;
    await this.posts.save(post);
    const [view] = await this.decoratePosts([post], id, me);
    return view;
  }

  async toggleLike(
    id: string,
    postId: string,
    me: AuthUser,
  ): Promise<{ liked: boolean; likeCount: number }> {
    await this.get(id, me);
    const post = await this.requirePost(id, postId);
    const existing = await this.likes.findOne({
      where: { postId, userId: me.id },
    });
    if (existing) {
      await this.likes.remove(existing);
      await this.posts.decrement({ id: postId }, 'likeCount', 1);
      return { liked: false, likeCount: Math.max(0, post.likeCount - 1) };
    }
    await this.likes.save(this.likes.create({ postId, userId: me.id }));
    await this.posts.increment({ id: postId }, 'likeCount', 1);
    return { liked: true, likeCount: post.likeCount + 1 };
  }

  async listComments(
    id: string,
    postId: string,
    me: AuthUser,
  ): Promise<ChannelPostComment[]> {
    await this.get(id, me);
    await this.requirePost(id, postId);
    return this.comments.find({
      where: { postId },
      relations: { author: true },
      order: { createdAt: 'ASC' },
    });
  }

  async addComment(
    id: string,
    postId: string,
    me: AuthUser,
    body: string,
  ): Promise<ChannelPostComment> {
    const channel = await this.requireChannel(id);
    const membership = await this.membership(id, me.id);
    if (!membership && !this.isStaff(me) && channel.ownerId !== me.id) {
      throw new ForbiddenException('Join the channel to comment');
    }
    await this.requirePost(id, postId);
    const comment = await this.comments.save(
      this.comments.create({ postId, authorId: me.id, body }),
    );
    await this.posts.increment({ id: postId }, 'commentCount', 1);
    return this.comments.findOne({
      where: { id: comment.id },
      relations: { author: true },
    }) as Promise<ChannelPostComment>;
  }

  async removeComment(
    id: string,
    postId: string,
    commentId: string,
    me: AuthUser,
  ): Promise<{ ok: boolean }> {
    const channel = await this.requireChannel(id);
    const post = await this.requirePost(id, postId);
    const comment = await this.comments.findOne({ where: { id: commentId } });
    if (!comment || comment.postId !== postId) {
      throw new NotFoundException('Comment not found');
    }
    const membership = await this.membership(id, me.id);
    const allowed =
      comment.authorId === me.id ||
      post.authorId === me.id ||
      this.canManage(channel, membership, me);
    if (!allowed) {
      throw new ForbiddenException('Not allowed to delete this comment');
    }
    await this.comments.remove(comment);
    await this.posts.decrement({ id: postId }, 'commentCount', 1);
    return { ok: true };
  }

  private async requireChannel(id: string): Promise<Channel> {
    const channel = await this.channels.findOne({ where: { id } });
    if (!channel) {
      throw new NotFoundException('Channel not found');
    }
    return channel;
  }

  private async requirePost(
    channelId: string,
    postId: string,
  ): Promise<ChannelPost> {
    const post = await this.posts.findOne({ where: { id: postId } });
    if (!post || post.channelId !== channelId) {
      throw new NotFoundException('Post not found');
    }
    return post;
  }

  private async membership(
    channelId: string,
    userId: string,
  ): Promise<ChannelMember | null> {
    return this.members.findOne({ where: { channelId, userId } });
  }

  private async assertAccess(channelId: string, me: AuthUser): Promise<void> {
    const channel = await this.channels.findOne({ where: { id: channelId } });
    if (!channel) {
      throw new NotFoundException('Channel not found');
    }
    if (channel.isPublic || this.isStaff(me) || channel.ownerId === me.id) {
      return;
    }
    if (await this.membership(channelId, me.id)) {
      return;
    }
    throw new NotFoundException('Channel not found');
  }

  private isStaff(me: AuthUser): boolean {
    return me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
  }

  private canManage(
    channel: Channel,
    membership: ChannelMember | null,
    me: AuthUser,
  ): boolean {
    if (this.isStaff(me) || channel.ownerId === me.id) return true;
    return membership?.role === ChannelRole.MODERATOR;
  }

  private async decorateChannels(
    channels: Channel[],
    viewerId: string,
  ): Promise<ChannelView[]> {
    if (channels.length === 0) return [];
    const ids = channels.map((c) => c.id);
    const [counts, mine] = await Promise.all([
      this.members
        .createQueryBuilder('m')
        .select('m.channelId', 'channelId')
        .addSelect('COUNT(*)', 'cnt')
        .where('m.channelId IN (:...ids)', { ids })
        .groupBy('m.channelId')
        .getRawMany<{ channelId: string; cnt: string }>(),
      this.members.find({
        where: { channelId: In(ids), userId: viewerId },
      }),
    ]);
    const countMap = new Map(counts.map((c) => [c.channelId, Number(c.cnt)]));
    const roleMap = new Map(mine.map((m) => [m.channelId, m.role]));
    return channels.map((c) =>
      Object.assign(c, {
        subscriberCount: countMap.get(c.id) ?? 0,
        isMember: roleMap.has(c.id),
        myRole: roleMap.get(c.id) ?? null,
      }) as ChannelView,
    );
  }

  private async decoratePosts(
    posts: ChannelPost[],
    channelId: string,
    me: AuthUser,
  ): Promise<ChannelPostView[]> {
    if (posts.length === 0) return [];
    const ids = posts.map((p) => p.id);
    const liked = await this.likes.find({
      where: { postId: In(ids), userId: me.id },
      select: { postId: true },
    });
    const likedSet = new Set(liked.map((l) => l.postId));
    const channel = await this.channels.findOne({ where: { id: channelId } });
    const membership = await this.membership(channelId, me.id);
    const canManage = channel ? this.canManage(channel, membership, me) : false;
    return posts.map((p) =>
      Object.assign(p, {
        likedByMe: likedSet.has(p.id),
        canDelete: p.authorId === me.id || canManage,
        canPin: canManage,
      }) as ChannelPostView,
    );
  }

  private async uniqueSlug(name: string): Promise<string> {
    const base =
      name
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 80) || 'channel';
    let candidate = base;
    let counter = 1;
    while (await this.channels.findOne({ where: { slug: candidate } })) {
      counter += 1;
      candidate = `${base}-${counter}`;
    }
    return candidate;
  }
}
