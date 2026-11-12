import { Controller, Get, Optional, Query, UseGuards } from '@nestjs/common';
import { FeedService, FeedResponse, SearchResponse } from './feed.service';
import {
  JwtAuthGuard,
  OptionalJwtAuthGuard,
  Public,
} from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';

@Controller('feed')
@UseGuards(JwtAuthGuard)
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get()
  feed(
    @CurrentUser() current: AuthUser,
    @Query('limit') limit?: string,
  ): Promise<FeedResponse> {
    return this.feedService.feed(
      limit ? Number(limit) : undefined,
      current.id,
    );
  }
}

@Controller('search')
@Public()
@UseGuards(OptionalJwtAuthGuard)
export class SearchController {
  constructor(private readonly feedService: FeedService) {}

  @Get()
  search(
    @Optional() @CurrentUser() current?: AuthUser | null,
    @Query('q') q?: string,
    @Query('limit') limit?: string,
  ): Promise<SearchResponse> {
    return this.feedService.search(q, limit ? Number(limit) : undefined, current?.id);
  }
}