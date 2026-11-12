import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../users/user.entity';
import { News } from './news.entity';
import { CreateNewsDto, UpdateNewsDto } from './dto/news.dto';

export interface Paginated<T> {
  items: T[];
  hasMore: boolean;
}

@Injectable()
export class NewsService {
  constructor(
    @InjectRepository(News)
    private readonly news: Repository<News>,
  ) {}

  async list(
    me: AuthUser,
    options: { limit?: number; offset?: number; includeDrafts?: boolean } = {},
  ): Promise<Paginated<News>> {
    const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);
    const offset = Math.max(options.offset ?? 0, 0);
    const qb = this.news
      .createQueryBuilder('news')
      .leftJoinAndSelect('news.author', 'author')
      .orderBy('news.createdAt', 'DESC')
      .take(limit + 1)
      .skip(offset);

    const staff =
      me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
    if (!(staff && options.includeDrafts)) {
      qb.andWhere('news.isPublished = true');
    }
    const rows = await qb.getMany();
    const hasMore = rows.length > limit;
    return { items: rows.slice(0, limit), hasMore };
  }

  async get(id: string, me: AuthUser): Promise<News> {
    const item = await this.news.findOne({
      where: { id },
      relations: { author: true },
    });
    if (!item) {
      throw new NotFoundException('News not found');
    }
    const staff =
      me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
    if (!item.isPublished && !staff) {
      throw new NotFoundException('News not found');
    }
    return item;
  }

  async create(me: AuthUser, dto: CreateNewsDto): Promise<News> {
    const item = await this.news.save(
      this.news.create({
        title: dto.title,
        body: dto.body,
        coverUrl: dto.coverUrl ?? null,
        authorId: me.id,
        isPublished: dto.isPublished ?? true,
      }),
    );
    return this.get(item.id, me);
  }

  async update(id: string, me: AuthUser, dto: UpdateNewsDto): Promise<News> {
    const item = await this.get(id, me);
    if (dto.title !== undefined) item.title = dto.title;
    if (dto.body !== undefined) item.body = dto.body;
    if (dto.coverUrl !== undefined) item.coverUrl = dto.coverUrl;
    if (dto.isPublished !== undefined) item.isPublished = dto.isPublished;
    await this.news.save(item);
    return this.get(id, me);
  }

  async remove(id: string, me: AuthUser): Promise<{ ok: boolean }> {
    const item = await this.get(id, me);
    await this.news.remove(item);
    return { ok: true };
  }
}
