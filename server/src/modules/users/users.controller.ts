import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { UsersService, UserProfileView } from './users.service';
import { User } from './user.entity';
import { UpdateUserDto } from './dto/update-user.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'moderator')
  @Get()
  list(): Promise<User[]> {
    return this.usersService.list();
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@CurrentUser() current: AuthUser): Promise<User> {
    return this.usersService.findById(current.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMe(
    @CurrentUser() current: AuthUser,
    @Body() dto: UpdateUserDto,
  ): Promise<User> {
    return this.usersService.update(current.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  async deleteMe(@CurrentUser() current: AuthUser): Promise<{ ok: boolean }> {
    await this.usersService.remove(current.id);
    return { ok: true };
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id/profile')
  profile(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<UserProfileView> {
    return this.usersService.getProfile(current, id);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async get(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<Partial<User>> {
    const view = await this.usersService.getProfile(current, id);
    return view.user;
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin', 'moderator')
  @Post()
  create(@Body() body: Partial<User>): Promise<User> {
    return this.usersService.create(body);
  }
}