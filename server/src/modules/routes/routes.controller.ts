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
import {
  JwtAuthGuard,
  OptionalJwtAuthGuard,
} from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { RoutesService, RouteView } from './routes.service';
import { CreateRouteDto } from './dto/create-route.dto';
import { UpdateRouteDto } from './dto/update-route.dto';

@Controller('routes')
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  /**
   * Список справочника. Публичный: аноним видит опубликованные,
   * авторизованный — ещё и собственные черновики, админ — все (?all=true).
   */
  @UseGuards(OptionalJwtAuthGuard)
  @Get()
  list(
    @Query('waterbodyId') waterbodyId?: string,
    @Query('all') all?: string,
    @Query('region') region?: string,
    @Query('farEast') farEast?: string,
    @CurrentUser() user?: AuthUser,
  ): Promise<RouteView[]> {
    return this.routesService.findAll(
      waterbodyId,
      user,
      all === 'true' || all === '1',
      region,
      farEast === 'true' || farEast === '1',
    );
  }

  /** Детали маршрута — видит каждый (без авторизации). */
  @Public()
  @Get(':id')
  get(@Param('id') id: string): Promise<RouteView> {
    return this.routesService.findById(id);
  }

  /** Создание маршрута — только авторизованные. */
  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @CurrentUser() current: AuthUser,
    @Body() dto: CreateRouteDto,
  ): Promise<RouteView> {
    return this.routesService.create(current.id, dto);
  }

  /** Изменение — автор маршрута или администратор. */
  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateRouteDto,
  ): Promise<RouteView> {
    return this.routesService.update(id, current, dto);
  }

  /** Удаление — автор маршрута или администратор. */
  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ ok: boolean }> {
    return this.routesService.remove(id, current);
  }
}
