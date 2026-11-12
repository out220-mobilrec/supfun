import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Review } from './review.entity';
import { Track } from '../tracks/track.entity';
import { Event } from '../events/event.entity';
import { ReviewsService } from './reviews.service';
import { ReviewsController } from './reviews.controller';

@Module({
  // Track и Event подключены только как репозитории — проверка существования цели,
  // без импорта TracksModule/EventsModule, чтобы не зацикливать модули.
  imports: [TypeOrmModule.forFeature([Review, Track, Event])],
  controllers: [ReviewsController],
  providers: [ReviewsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
