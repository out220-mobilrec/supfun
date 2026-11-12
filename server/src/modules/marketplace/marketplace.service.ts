import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { In, Repository } from 'typeorm';
import { Listing, ListingStatus } from './listing.entity';
import {
  ListingLead,
  ListingLeadStatus,
} from './listing-lead.entity';
import { ListingFavorite } from './listing-favorite.entity';
import { ListingReview } from './listing-review.entity';
import { CreateListingDto } from './dto/create-listing.dto';
import { UpdateListingDto } from './dto/update-listing.dto';
import { CreateLeadDto } from './dto/create-lead.dto';
import { CreateReviewDto } from './dto/create-review.dto';

export interface ListingFilters {
  category?: string;
  q?: string;
  minPrice?: number;
  maxPrice?: number;
  status?: ListingStatus;
  city?: string;
  sellerId?: string;
  sort?: 'newest' | 'price_asc' | 'price_desc';
  limit?: number;
  offset?: number;
}

export type MarketplaceReview = Omit<ListingReview, 'author'> & {
  author?: { id: string; name: string; avatarUrl: string | null };
};

@Injectable()
export class MarketplaceService {
  constructor(
    @InjectRepository(Listing)
    private readonly listingsRepository: Repository<Listing>,
    @InjectRepository(ListingLead)
    private readonly leadsRepository: Repository<ListingLead>,
    @InjectRepository(ListingFavorite)
    private readonly favoritesRepository: Repository<ListingFavorite>,
    @InjectRepository(ListingReview)
    private readonly reviewsRepository: Repository<ListingReview>,
    private readonly eventEmitter: EventEmitter2,
    private readonly config: ConfigService,
  ) {}

  async create(me: string, dto: CreateListingDto): Promise<Listing> {
    const autoApprove = this.config.get<boolean>('marketplace.autoApprove');
    const status = autoApprove ? ListingStatus.ACTIVE : ListingStatus.MODERATION;
    const listing = this.listingsRepository.create({
      sellerId: me,
      category: dto.category,
      title: dto.title,
      description: dto.description ?? null,
      price: dto.price ?? null,
      currency: dto.currency ?? 'RUB',
      photos: dto.photos ?? [],
      latitude: dto.latitude ?? null,
      longitude: dto.longitude ?? null,
      city: dto.city ?? null,
      status,
      publishedAt: autoApprove ? new Date() : null,
    });
    return this.listingsRepository.save(listing);
  }

  async update(me: string, id: string, dto: UpdateListingDto): Promise<Listing> {
    const listing = await this.ownedOr404(me, id);
    if (listing.status !== ListingStatus.ACTIVE) {
      throw new BadRequestException('Cannot update a completed or removed listing');
    }
    Object.assign(listing, {
      category: dto.category ?? listing.category,
      title: dto.title ?? listing.title,
      description: dto.description !== undefined ? dto.description : listing.description,
      price: dto.price !== undefined ? dto.price : listing.price,
      currency: dto.currency ?? listing.currency,
      photos: dto.photos ?? listing.photos,
      latitude: dto.latitude !== undefined ? dto.latitude : listing.latitude,
      longitude: dto.longitude !== undefined ? dto.longitude : listing.longitude,
      city: dto.city !== undefined ? dto.city : listing.city,
    });
    return this.listingsRepository.save(listing);
  }

  async remove(me: string, id: string): Promise<{ ok: boolean }> {
    const listing = await this.ownedOr404(me, id);
    listing.status = ListingStatus.REMOVED;
    await this.listingsRepository.save(listing);
    return { ok: true };
  }

  async markCompleted(me: string, id: string): Promise<Listing> {
    const listing = await this.ownedOr404(me, id);
    if (listing.status !== ListingStatus.ACTIVE) {
      throw new BadRequestException('Listing is already completed or removed');
    }
    listing.status = ListingStatus.COMPLETED;
    return this.listingsRepository.save(listing);
  }

  async list(filters: ListingFilters = {}): Promise<Listing[]> {
    const qb = this.listingsRepository
      .createQueryBuilder('listing')
      .leftJoinAndSelect('listing.seller', 'seller')
      .where('listing.status = :status', {
        status: filters.status ?? ListingStatus.ACTIVE,
      });
    if (filters.category) {
      qb.andWhere('listing.category = :category', { category: filters.category });
    }
    if (filters.q) {
      qb.andWhere('listing.title ILIKE :q', { q: `%${filters.q}%` });
    }
    if (filters.minPrice != null) {
      qb.andWhere('listing.price >= :minPrice', { minPrice: filters.minPrice });
    }
    if (filters.maxPrice != null) {
      qb.andWhere('listing.price <= :maxPrice', { maxPrice: filters.maxPrice });
    }
    if (filters.city) {
      qb.andWhere('listing.city ILIKE :city', { city: `%${filters.city}%` });
    }
    if (filters.sellerId) {
      qb.andWhere('listing.sellerId = :sellerId', { sellerId: filters.sellerId });
    }
    const take = Math.min(Math.max(filters.limit ?? 50, 1), 100);
    const skip = Math.max(filters.offset ?? 0, 0);
    if (filters.sort === 'price_asc') {
      qb.orderBy('listing.price', 'ASC', 'NULLS LAST');
    } else if (filters.sort === 'price_desc') {
      qb.orderBy('listing.price', 'DESC', 'NULLS LAST');
    } else {
      qb.orderBy('listing.createdAt', 'DESC');
    }
    return qb.take(take).skip(skip).getMany();
  }

  async toggleFavorite(me: string, listingId: string): Promise<{ favorite: boolean }> {
    const listing = await this.findOne(listingId);
    const existing = await this.favoritesRepository.findOne({
      where: { userId: me, listingId: listing.id },
    });
    if (existing) {
      await this.favoritesRepository.remove(existing);
      return { favorite: false };
    }
    await this.favoritesRepository.save(
      this.favoritesRepository.create({ userId: me, listingId: listing.id }),
    );
    return { favorite: true };
  }

  async favorites(me: string): Promise<Listing[]> {
    const rows = await this.favoritesRepository.find({
      where: { userId: me },
      relations: { listing: { seller: true } },
      order: { createdAt: 'DESC' },
    });
    return rows
      .map((r) => r.listing)
      .filter((l) => l && l.status !== ListingStatus.REMOVED);
  }

  async favoriteIds(me: string): Promise<string[]> {
    const rows = await this.favoritesRepository.find({
      where: { userId: me },
      select: { listingId: true },
    });
    return rows.map((r) => r.listingId);
  }

  async createReview(
    me: string,
    listingId: string,
    dto: CreateReviewDto,
  ): Promise<ListingReview> {
    const listing = await this.findOne(listingId);
    if (listing.sellerId === me) {
      throw new BadRequestException('Cannot review your own listing');
    }
    const lead = await this.leadsRepository.findOne({
      where: {
        listingId,
        buyerId: me,
        status: In([ListingLeadStatus.ACCEPTED, ListingLeadStatus.CLOSED]),
      },
    });
    if (!lead) {
      throw new ForbiddenException(
        'You can review only after an accepted deal with the seller',
      );
    }
    const existing = await this.reviewsRepository.findOne({
      where: { listingId, authorId: me },
    });
    if (existing) {
      throw new BadRequestException('You have already reviewed this listing');
    }
    return this.reviewsRepository.save(
      this.reviewsRepository.create({
        listingId,
        authorId: me,
        targetId: listing.sellerId,
        rating: dto.rating,
        comment: dto.comment ?? null,
      }),
    );
  }

  async userReviews(userId: string): Promise<MarketplaceReview[]> {
    const reviews = await this.reviewsRepository.find({
      where: { targetId: userId },
      relations: { author: true, listing: true },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return reviews.map((r) => this.toReviewView(r));
  }

  async listingReviews(listingId: string): Promise<MarketplaceReview[]> {
    await this.findOne(listingId);
    const reviews = await this.reviewsRepository.find({
      where: { listingId },
      relations: { author: true },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return reviews.map((r) => this.toReviewView(r));
  }

  private toReviewView(r: ListingReview): MarketplaceReview {
    return {
      ...r,
      author: r.author
        ? { id: r.author.id, name: r.author.name, avatarUrl: r.author.avatarUrl }
        : undefined,
    };
  }

  async sellerRating(userId: string): Promise<{ average: number; count: number }> {
    const row = await this.reviewsRepository
      .createQueryBuilder('review')
      .select('AVG(review.rating)', 'average')
      .addSelect('COUNT(*)', 'count')
      .where('review.targetId = :userId', { userId })
      .getRawOne<{ average: string | null; count: string }>();
    return {
      average: row?.average ? Math.round(Number(row.average) * 10) / 10 : 0,
      count: Number(row?.count ?? 0),
    };
  }

  async findMine(me: string): Promise<Listing[]> {
    return this.listingsRepository.find({
      where: { sellerId: me },
      relations: { seller: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Listing> {
    const listing = await this.listingsRepository.findOne({
      where: { id },
      relations: { seller: true },
    });
    if (!listing || listing.status === ListingStatus.REMOVED) {
      throw new NotFoundException(`Listing ${id} not found`);
    }
    return listing;
  }

  async createLead(
    me: string,
    listingId: string,
    dto: CreateLeadDto,
  ): Promise<ListingLead> {
    const listing = await this.findOne(listingId);
    if (listing.sellerId === me) {
      throw new BadRequestException('Cannot contact your own listing');
    }
    if (listing.status !== ListingStatus.ACTIVE) {
      throw new BadRequestException('Listing is not active');
    }
    const existing = await this.leadsRepository.findOne({
      where: { listingId, buyerId: me },
      order: { createdAt: 'DESC' },
    });
    if (existing && existing.status === ListingLeadStatus.NEW) {
      throw new BadRequestException('You already have an active inquiry for this listing');
    }
    const lead = await this.leadsRepository.save(
      this.leadsRepository.create({
        listingId,
        buyerId: me,
        message: dto.message ?? null,
      }),
    );
    this.eventEmitter.emit('listings.lead', {
      sellerId: listing.sellerId,
      buyerId: me,
      listingId,
      listingTitle: listing.title,
      leadId: lead.id,
    });
    return lead;
  }

  async sellerLeads(me: string, listingId?: string): Promise<ListingLead[]> {
    const qb = this.leadsRepository
      .createQueryBuilder('lead')
      .leftJoinAndSelect('lead.listing', 'listing')
      .where('listing.sellerId = :me', { me });
    if (listingId) {
      qb.andWhere('lead.listingId = :listingId', { listingId });
    }
    return qb.orderBy('lead.createdAt', 'DESC').getMany();
  }

  async buyerLeads(me: string): Promise<ListingLead[]> {
    return this.leadsRepository.find({
      where: { buyerId: me },
      relations: { listing: true },
      order: { createdAt: 'DESC' },
    });
  }

  async updateLead(
    me: string,
    leadId: string,
    status: ListingLeadStatus,
  ): Promise<ListingLead> {
    const lead = await this.leadsRepository.findOne({
      where: { id: leadId },
      relations: { listing: true },
    });
    if (!lead) {
      throw new NotFoundException(`Lead ${leadId} not found`);
    }
    if (lead.listing.sellerId !== me) {
      throw new ForbiddenException('Only the seller can respond to this inquiry');
    }
    if (lead.status === ListingLeadStatus.CLOSED) {
      throw new BadRequestException('Inquiry is already closed');
    }
    lead.status = status;
    const saved = await this.leadsRepository.save(lead);
    if (status === ListingLeadStatus.ACCEPTED) {
      this.eventEmitter.emit('listings.lead_accepted', {
        buyerId: lead.buyerId,
        sellerId: me,
        listingId: lead.listingId,
        listingTitle: lead.listing.title,
        leadId: saved.id,
      });
    }
    return saved;
  }

  private async ownedOr404(me: string, id: string): Promise<Listing> {
    const listing = await this.listingsRepository.findOne({ where: { id } });
    if (!listing) {
      throw new NotFoundException(`Listing ${id} not found`);
    }
    if (listing.sellerId !== me) {
      throw new ForbiddenException('Only the seller can manage this listing');
    }
    return listing;
  }
}