import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review, ReviewTargetType } from './review.entity';
import { Track } from '../tracks/track.entity';
import { Event } from '../events/event.entity';
import { UserRole } from '../users/user.entity';
import { CreateReviewDto, UpdateReviewDto } from './dto/review.dto';
import type { AuthUser } from '../../common/decorators/current-user.decorator';

export interface ReviewSummary {
  count: number;
  avgRating: number;
}

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review)
    private readonly reviewsRepository: Repository<Review>,
    @InjectRepository(Track)
    private readonly tracksRepository: Repository<Track>,
    @InjectRepository(Event)
    private readonly eventsRepository: Repository<Event>,
  ) {}

  /** Отзывы о маршруте/заплыве, свежие сверху. */
  async list(targetType: ReviewTargetType, targetId: string): Promise<Review[]> {
    await this.assertTargetExists(targetType, targetId);
    return this.reviewsRepository.find({
      where: { targetType, targetId },
      relations: { author: true },
      order: { createdAt: 'DESC' },
    });
  }

  async summary(targetType: ReviewTargetType, targetId: string): Promise<ReviewSummary> {
    const rows: { count: string; avg: string | null }[] = await this.reviewsRepository
      .createQueryBuilder('review')
      .select('COUNT(*)::int', 'count')
      .addSelect('AVG(review.rating)', 'avg')
      .where('review.targetType = :targetType', { targetType })
      .andWhere('review.targetId = :targetId', { targetId })
      .getRawMany();
    return {
      count: Number(rows[0]?.count ?? 0),
      avgRating: Number(rows[0]?.avg ?? 0),
    };
  }

  /**
   * Отзыв автора на цель: повторная отправка обновляет существующий —
   * на один объект у одного пользователя ровно один отзыв.
   */
  async upsert(authorId: string, dto: CreateReviewDto): Promise<Review> {
    await this.assertTargetExists(dto.targetType, dto.targetId);

    const existing = await this.reviewsRepository.findOne({
      where: {
        targetType: dto.targetType,
        targetId: dto.targetId,
        authorId,
      },
    });

    if (existing) {
      existing.rating = dto.rating;
      existing.comment = dto.comment ?? null;
      existing.photos = dto.photos ?? [];
      return this.withAuthor(await this.reviewsRepository.save(existing));
    }

    const created = await this.reviewsRepository.save(
      this.reviewsRepository.create({
        targetType: dto.targetType,
        targetId: dto.targetId,
        authorId,
        rating: dto.rating,
        comment: dto.comment ?? null,
        photos: dto.photos ?? [],
      }),
    );
    return this.withAuthor(created);
  }

  async update(id: string, me: AuthUser, dto: UpdateReviewDto): Promise<Review> {
    const review = await this.ensureOwned(id, me);
    if (dto.rating !== undefined) review.rating = dto.rating;
    if (dto.comment !== undefined) review.comment = dto.comment;
    if (dto.photos !== undefined) review.photos = dto.photos;
    return this.withAuthor(await this.reviewsRepository.save(review));
  }

  async remove(id: string, me: AuthUser): Promise<{ ok: boolean }> {
    const review = await this.ensureOwned(id, me);
    await this.reviewsRepository.remove(review);
    return { ok: true };
  }

  private async ensureOwned(id: string, me: AuthUser): Promise<Review> {
    const review = await this.reviewsRepository.findOne({ where: { id } });
    if (!review) {
      throw new NotFoundException(`Review ${id} not found`);
    }
    const staff = me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
    if (review.authorId !== me.id && !staff) {
      throw new ForbiddenException('Not your review');
    }
    return review;
  }

  private async withAuthor(review: Review): Promise<Review> {
    const full = await this.reviewsRepository.findOne({
      where: { id: review.id },
      relations: { author: true },
    });
    if (!full) {
      throw new NotFoundException(`Review ${review.id} not found`);
    }
    return full;
  }

  /** Полиморфная цель: проверяем, что маршрут/заплыв существует. */
  private async assertTargetExists(targetType: ReviewTargetType, targetId: string): Promise<void> {
    if (targetType === ReviewTargetType.TRACK) {
      const found = await this.tracksRepository.exist({ where: { id: targetId } });
      if (!found) throw new NotFoundException(`Track ${targetId} not found`);
      return;
    }
    if (targetType === ReviewTargetType.EVENT) {
      const found = await this.eventsRepository.exist({ where: { id: targetId } });
      if (!found) throw new NotFoundException(`Event ${targetId} not found`);
      return;
    }
    throw new BadRequestException(`Неизвестный тип цели: ${targetType}`);
  }
}
