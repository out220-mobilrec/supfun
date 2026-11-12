import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsUUID } from 'class-validator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { BlocksService } from './blocks.service';
import { User } from '../users/user.entity';

class BlockUserDto {
  @IsUUID()
  userId: string;
}

@UseGuards(JwtAuthGuard)
@Controller('blocks')
export class BlocksController {
  constructor(private readonly service: BlocksService) {}

  @Get()
  list(@CurrentUser() current: AuthUser): Promise<User[]> {
    return this.service.list(current.id);
  }

  @Post()
  block(
    @CurrentUser() current: AuthUser,
    @Body() dto: BlockUserDto,
  ): Promise<{ ok: boolean }> {
    return this.service.block(current.id, dto.userId);
  }

  @Delete(':userId')
  unblock(
    @CurrentUser() current: AuthUser,
    @Param('userId') userId: string,
  ): Promise<{ ok: boolean }> {
    return this.service.unblock(current.id, userId);
  }
}
