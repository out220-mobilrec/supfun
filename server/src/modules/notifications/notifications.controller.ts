import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseEnumPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import {
  NotificationsService,
  NotificationSettingView,
} from './notifications.service';
import { Notification } from './notification.entity';
import { NotificationCategory } from './notification-setting.entity';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateNotificationSettingDto } from './dto/update-notification-setting.dto';
import { DevicePlatform } from './device-token.entity';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(
    @CurrentUser() current: AuthUser,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ): Promise<Notification[]> {
    return this.notificationsService.list(
      current.id,
      limit ? Number(limit) : undefined,
      before,
    );
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() current: AuthUser): Promise<{ count: number }> {
    return this.notificationsService.unreadCount(current.id);
  }

  @Get('settings')
  settings(@CurrentUser() current: AuthUser): Promise<NotificationSettingView[]> {
    return this.notificationsService.settings(current.id);
  }

  @Patch('settings/:category')
  updateSetting(
    @CurrentUser() current: AuthUser,
    @Param('category', new ParseEnumPipe(NotificationCategory))
    category: NotificationCategory,
    @Body() dto: UpdateNotificationSettingDto,
  ): Promise<NotificationSettingView> {
    return this.notificationsService.updateSetting(current.id, category, dto);
  }

  @Post('read')
  markRead(
    @CurrentUser() current: AuthUser,
    @Body() body: { id?: string },
  ): Promise<{ ok: boolean }> {
    return this.notificationsService.markRead(current.id, body?.id);
  }

  @Delete(':id')
  remove(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ ok: boolean }> {
    return this.notificationsService.remove(current.id, id);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('devices')
export class DevicesController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('register')
  register(
    @CurrentUser() current: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<{ ok: boolean }> {
    return this.notificationsService.registerDevice(
      current.id,
      dto.token,
      dto.platform ?? DevicePlatform.ANDROID,
    );
  }

  @Delete(':token')
  unregister(
    @CurrentUser() current: AuthUser,
    @Param('token') token: string,
  ): Promise<{ ok: boolean }> {
    return this.notificationsService.unregisterDevice(current.id, token);
  }
}