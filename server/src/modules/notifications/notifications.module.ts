import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MessagesModule } from '../messages/messages.module';
import { Notification } from './notification.entity';
import { NotificationSetting } from './notification-setting.entity';
import { DeviceToken } from './device-token.entity';
import { NotificationsService } from './notifications.service';
import { PushService } from './push.service';
import {
  DevicesController,
  NotificationsController,
} from './notifications.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Notification, NotificationSetting, DeviceToken]),
    MessagesModule,
  ],
  controllers: [NotificationsController, DevicesController],
  providers: [NotificationsService, PushService],
  exports: [NotificationsService],
})
export class NotificationsModule {}