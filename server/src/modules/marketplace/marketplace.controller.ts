import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { MarketplaceService, ListingFilters } from './marketplace.service';
import { Listing, ListingStatus } from './listing.entity';
import {
  ListingLead,
  ListingLeadStatus,
} from './listing-lead.entity';
import { CreateListingDto } from './dto/create-listing.dto';
import { UpdateListingDto } from './dto/update-listing.dto';
import { CreateLeadDto } from './dto/create-lead.dto';
import { CreateReviewDto } from './dto/create-review.dto';
import { LISTING_CATEGORIES } from './categories';

@Controller('marketplace/listings')
export class MarketplaceController {
  constructor(private readonly service: MarketplaceService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @CurrentUser() current: AuthUser,
    @Body() dto: CreateListingDto,
  ): Promise<Listing> {
    return this.service.create(current.id, dto);
  }

  @Get()
  list(
    @Query('category') category?: string,
    @Query('q') q?: string,
    @Query('minPrice') minPrice?: string,
    @Query('maxPrice') maxPrice?: string,
    @Query('status') status?: string,
    @Query('city') city?: string,
    @Query('sellerId') sellerId?: string,
    @Query('sort') sort?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ): Promise<Listing[]> {
    const filters: ListingFilters = {
      category,
      q,
      minPrice: minPrice != null ? Number(minPrice) : undefined,
      maxPrice: maxPrice != null ? Number(maxPrice) : undefined,
      status: status as ListingStatus | undefined,
      city,
      sellerId,
      sort: sort as ListingFilters['sort'],
      limit: limit != null ? Number(limit) : undefined,
      offset: offset != null ? Number(offset) : undefined,
    };
    if (
      filters.status &&
      !Object.values(ListingStatus).includes(filters.status)
    ) {
      throw new BadRequestException('Invalid status');
    }
    return this.service.list(filters);
  }

  @UseGuards(JwtAuthGuard)
  @Get('mine')
  findMine(@CurrentUser() current: AuthUser): Promise<Listing[]> {
    return this.service.findMine(current.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string): Promise<Listing> {
    return this.service.findOne(id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateListingDto,
  ): Promise<Listing> {
    return this.service.update(current.id, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ ok: boolean }> {
    return this.service.remove(current.id, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/complete')
  complete(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<Listing> {
    return this.service.markCompleted(current.id, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/leads')
  lead(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateLeadDto,
  ): Promise<ListingLead> {
    return this.service.createLead(current.id, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id/favorite')
  favorite(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ favorite: boolean }> {
    return this.service.toggleFavorite(current.id, id);
  }

  @Get(':id/reviews')
  reviews(@Param('id') id: string) {
    return this.service.listingReviews(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/reviews')
  createReview(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.service.createReview(current.id, id, dto);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('marketplace/favorites')
export class MarketplaceFavoritesController {
  constructor(private readonly service: MarketplaceService) {}

  @Get()
  list(@CurrentUser() current: AuthUser): Promise<Listing[]> {
    return this.service.favorites(current.id);
  }
}

@Controller('marketplace/users')
export class MarketplaceUsersController {
  constructor(private readonly service: MarketplaceService) {}

  @Get(':id/reviews')
  reviews(@Param('id') id: string) {
    return this.service.userReviews(id);
  }

  @Get(':id/rating')
  rating(@Param('id') id: string) {
    return this.service.sellerRating(id);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('marketplace/leads')
export class MarketplaceLeadsController {
  constructor(private readonly service: MarketplaceService) {}

  @Get('mine')
  mine(@CurrentUser() current: AuthUser): Promise<ListingLead[]> {
    return this.service.buyerLeads(current.id);
  }

  @Get('for-me')
  forMe(
    @CurrentUser() current: AuthUser,
    @Query('listingId') listingId?: string,
  ): Promise<ListingLead[]> {
    return this.service.sellerLeads(current.id, listingId);
  }

  @Post(':id/status')
  updateStatus(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() body: { status: ListingLeadStatus },
  ): Promise<ListingLead> {
    if (!Object.values(ListingLeadStatus).includes(body.status)) {
      throw new BadRequestException('Invalid lead status');
    }
    return this.service.updateLead(current.id, id, body.status);
  }
}

// categories endpoint stays tree-shakeable and separate
@Controller()
export class MarketplaceMetaController {
  @Get('marketplace/categories')
  categories(): string[] {
    return [...LISTING_CATEGORIES];
  }
}