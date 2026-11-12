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
import {
  CurrentUser,
  type AuthUser,
} from '../../common/decorators/current-user.decorator';
import { GearService } from './gear.service';
import { CreateGearDto, UpdateGearDto } from './dto/gear.dto';

@Controller('gear')
@UseGuards(JwtAuthGuard)
export class GearController {
  constructor(private readonly gearService: GearService) {}

  @Get('mine')
  mine(@CurrentUser() me: AuthUser) {
    return this.gearService.listMine(me.id);
  }

  @Get(':userId')
  listForUser(
    @CurrentUser() me: AuthUser,
    @Param('userId') userId: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.gearService.listForUser(me.id, userId, {
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Post()
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateGearDto) {
    return this.gearService.create(me.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateGearDto,
  ) {
    return this.gearService.update(me.id, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.gearService.remove(me.id, id);
  }
}