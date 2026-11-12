import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Listing } from './listing.entity';
import { ListingLead } from './listing-lead.entity';
import { ListingFavorite } from './listing-favorite.entity';
import { ListingReview } from './listing-review.entity';
import { MarketplaceService } from './marketplace.service';
import {
  MarketplaceController,
  MarketplaceLeadsController,
  MarketplaceMetaController,
  MarketplaceFavoritesController,
  MarketplaceUsersController,
} from './marketplace.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Listing,
      ListingLead,
      ListingFavorite,
      ListingReview,
    ]),
  ],
  controllers: [
    MarketplaceController,
    MarketplaceLeadsController,
    MarketplaceMetaController,
    MarketplaceFavoritesController,
    MarketplaceUsersController,
  ],
  providers: [MarketplaceService],
  exports: [MarketplaceService],
})
export class MarketplaceModule {}