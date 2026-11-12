import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { FriendsService } from './friends.service';
import { FriendRequest } from './friend-request.entity';
import { User } from '../users/user.entity';
import { SendFriendRequestDto } from './dto/send-friend-request.dto';

@UseGuards(JwtAuthGuard)
@Controller('friends')
export class FriendsController {
  constructor(private readonly service: FriendsService) {}

  @Get()
  list(@CurrentUser() current: AuthUser): Promise<User[]> {
    return this.service.list(current.id);
  }

  @Get('requests/incoming')
  incoming(@CurrentUser() current: AuthUser): Promise<FriendRequest[]> {
    return this.service.incoming(current.id);
  }

  @Get('requests/outgoing')
  outgoing(@CurrentUser() current: AuthUser): Promise<FriendRequest[]> {
    return this.service.outgoing(current.id);
  }

  @Post('requests')
  send(
    @CurrentUser() current: AuthUser,
    @Body() dto: SendFriendRequestDto,
  ): Promise<FriendRequest> {
    return this.service.send(current.id, dto.userId);
  }

  @Post('requests/:id/accept')
  accept(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<FriendRequest> {
    return this.service.accept(current.id, id);
  }

  @Post('requests/:id/reject')
  reject(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    return this.service.reject(current.id, id);
  }

  @Delete('requests/:id')
  cancel(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    return this.service.cancel(current.id, id);
  }

  @Delete(':userId')
  remove(@CurrentUser() current: AuthUser, @Param('userId') userId: string): Promise<{ ok: boolean }> {
    return this.service.remove(current.id, userId);
  }
}