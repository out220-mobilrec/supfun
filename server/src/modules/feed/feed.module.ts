import { Module } from '@nestjs/common';
import { FeedService } from './feed.service';
import { FeedController, SearchController } from './feed.controller';

@Module({
  controllers: [FeedController, SearchController],
  providers: [FeedService],
})
export class FeedModule {}