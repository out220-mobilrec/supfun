import {
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
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  CurrentUser,
  type AuthUser,
} from '../../common/decorators/current-user.decorator';
import { NewsService } from './news.service';
import { CreateNewsDto, UpdateNewsDto } from './dto/news.dto';

@Controller('news')
@UseGuards(JwtAuthGuard)
export class NewsController {
  constructor(private readonly newsService: NewsService) {}

  @Get()
  list(
    @CurrentUser() me: AuthUser,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('includeDrafts') includeDrafts?: string,
  ) {
    return this.newsService.list(me, {
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
      includeDrafts: includeDrafts === 'true',
    });
  }

  @Get(':id')
  get(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.newsService.get(id, me);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('admin', 'moderator')
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateNewsDto) {
    return this.newsService.create(me, dto);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('admin', 'moderator')
  update(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateNewsDto,
  ) {
    return this.newsService.update(id, me, dto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('admin', 'moderator')
  remove(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.newsService.remove(id, me);
  }
}
