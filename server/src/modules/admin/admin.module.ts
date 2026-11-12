import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../users/user.entity';
import { Event } from '../events/event.entity';
import { Track } from '../tracks/track.entity';
import { Listing } from '../marketplace/listing.entity';
import { ListingLead } from '../marketplace/listing-lead.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Event,
      Track,
      Listing,
      ListingLead,
      WaterBody,
    ]),
  ],
  providers: [AdminService],
  controllers: [AdminController],
})
export class AdminModule {}