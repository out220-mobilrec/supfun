import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { OnEvent } from '@nestjs/event-emitter';
import { Notification, NotificationType } from './notification.entity';
import {
  NotificationCategory,
  NotificationSetting,
  NOTIFICATION_CATEGORIES,
} from './notification-setting.entity';
import { DeviceToken, DevicePlatform } from './device-token.entity';
import { ChatGateway } from '../messages/chat.gateway';
import { PushService } from './push.service';
import { ACHIEVEMENTS, AchievementDef } from '../gamification/gamification.service';

export interface NotifyInput {
  userId: string;
  type: NotificationType;
  title: string;
  body?: string | null;
  data?: Record<string, unknown>;
}

export interface NotificationSettingView {
  category: NotificationCategory;
  inApp: boolean;
  push: boolean;
}

const TYPE_CATEGORY: Record<NotificationType, NotificationCategory> = {
  [NotificationType.MESSAGE]: NotificationCategory.MESSAGES,
  [NotificationType.FRIEND_REQUEST]: NotificationCategory.COMMUNITY,
  [NotificationType.FRIEND_ACCEPTED]: NotificationCategory.COMMUNITY,
  [NotificationType.ACHIEVEMENT]: NotificationCategory.ACHIEVEMENTS,
  [NotificationType.EVENT_INVITE]: NotificationCategory.EVENTS,
  [NotificationType.EVENT_JOINED]: NotificationCategory.EVENTS,
  [NotificationType.EVENT_REMINDER]: NotificationCategory.EVENTS,
  [NotificationType.MARKETPLACE]: NotificationCategory.MARKETPLACE,
  [NotificationType.NEWS]: NotificationCategory.NEWS,
  [NotificationType.WEATHER]: NotificationCategory.WEATHER,
  [NotificationType.SYSTEM]: NotificationCategory.COMMUNITY,
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notificationsRepository: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private readonly devicesRepository: Repository<DeviceToken>,
    @InjectRepository(NotificationSetting)
    private readonly settingsRepository: Repository<NotificationSetting>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly chatGateway: ChatGateway,
    private readonly pushService: PushService,
  ) {}

  async notify(input: NotifyInput): Promise<Notification | null> {
    const category = TYPE_CATEGORY[input.type] ?? NotificationCategory.COMMUNITY;
    const setting = await this.settingFor(input.userId, category);

    let saved: Notification | null = null;
    if (setting.inApp) {
      saved = await this.notificationsRepository.save(
        this.notificationsRepository.create({
          userId: input.userId,
          type: input.type,
          title: input.title,
          body: input.body ?? null,
          data: input.data ?? null,
        }),
      );
      this.chatGateway.pushToUser(input.userId, 'notify:new', saved);
    }

    if (setting.push) {
      const payload: Notification =
        saved ??
        this.notificationsRepository.create({
          id: 'transient',
          userId: input.userId,
          type: input.type,
          title: input.title,
          body: input.body ?? null,
          data: input.data ?? null,
        });
      void this.deliverPush(payload).catch((error) =>
        this.logger.warn(`push delivery failed: ${(error as Error).message}`),
      );
    }
    return saved;
  }

  async settings(me: string): Promise<NotificationSettingView[]> {
    const rows = await this.settingsRepository.find({ where: { userId: me } });
    const byCategory = new Map(rows.map((r) => [r.category, r]));
    return NOTIFICATION_CATEGORIES.map((category) => {
      const row = byCategory.get(category);
      return {
        category,
        inApp: row?.inApp ?? true,
        push: row?.push ?? true,
      };
    });
  }

  async updateSetting(
    me: string,
    category: NotificationCategory,
    patch: { inApp?: boolean; push?: boolean },
  ): Promise<NotificationSettingView> {
    let row = await this.settingsRepository.findOne({
      where: { userId: me, category },
    });
    if (!row) {
      row = this.settingsRepository.create({
        userId: me,
        category,
        inApp: true,
        push: true,
      });
    }
    if (patch.inApp !== undefined) row.inApp = patch.inApp;
    if (patch.push !== undefined) row.push = patch.push;
    const saved = await this.settingsRepository.save(row);
    return { category: saved.category, inApp: saved.inApp, push: saved.push };
  }

  private async settingFor(
    userId: string,
    category: NotificationCategory,
  ): Promise<{ inApp: boolean; push: boolean }> {
    const row = await this.settingsRepository.findOne({
      where: { userId, category },
    });
    return { inApp: row?.inApp ?? true, push: row?.push ?? true };
  }

  async list(me: string, limit = 50, before?: string): Promise<Notification[]> {
    const qb = this.notificationsRepository
      .createQueryBuilder('notification')
      .where('notification.userId = :me', { me })
      .orderBy('notification.createdAt', 'DESC')
      .take(Math.min(limit, 100));
    if (before) {
      qb.andWhere('notification.createdAt < :before', {
        before: new Date(before),
      });
    }
    return qb.getMany();
  }

  async unreadCount(me: string): Promise<{ count: number }> {
    const count = await this.notificationsRepository.count({
      where: { userId: me, isRead: false },
    });
    return { count };
  }

  async markRead(me: string, id?: string): Promise<{ ok: boolean }> {
    const qb = this.notificationsRepository
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true })
      .where('userId = :me AND isRead = false', { me });
    if (id) {
      qb.andWhere('id = :id', { id });
    }
    await qb.execute();
    return { ok: true };
  }

  async remove(me: string, id: string): Promise<{ ok: boolean }> {
    const notification = await this.notificationsRepository.findOne({
      where: { id, userId: me },
    });
    if (!notification) {
      throw new NotFoundException(`Notification ${id} not found`);
    }
    await this.notificationsRepository.remove(notification);
    return { ok: true };
  }

  async registerDevice(
    me: string,
    token: string,
    platform: DevicePlatform,
  ): Promise<{ ok: boolean }> {
    const existing = await this.devicesRepository.findOne({
      where: { token },
    });
    if (existing) {
      if (existing.userId === me) {
        existing.platform = platform;
        existing.lastUsedAt = new Date();
        await this.devicesRepository.save(existing);
        return { ok: true };
      }
      await this.devicesRepository.remove(existing);
    }
    await this.devicesRepository.save(
      this.devicesRepository.create({
        userId: me,
        token,
        platform,
        lastUsedAt: new Date(),
      }),
    );
    return { ok: true };
  }

  async unregisterDevice(me: string, token: string): Promise<{ ok: boolean }> {
    const device = await this.devicesRepository.findOne({
      where: { token, userId: me },
    });
    if (device) {
      await this.devicesRepository.remove(device);
    }
    return { ok: true };
  }

  @OnEvent('messages.sent')
  async handleMessageSent(payload: {
    senderId: string;
    conversationId: string;
    content: string | null;
  }): Promise<void> {
    const rows: { user_id: string }[] = await this.dataSource.query(
      `SELECT user_id FROM conversation_participants
       WHERE conversation_id = $1 AND user_id != $2`,
      [payload.conversationId, payload.senderId],
    );
    if (rows.length === 0) return;
    const senderName = await this.userName(payload.senderId);
    const body =
      (senderName ? `${senderName}: ` : '') +
      (payload.content?.slice(0, 120) ?? 'Новое сообщение');
    for (const row of rows) {
      await this.notify({
        userId: row.user_id,
        type: NotificationType.MESSAGE,
        title: 'Новое сообщение',
        body,
        data: { conversationId: payload.conversationId },
      });
    }
  }

  @OnEvent('friends.request')
  async handleFriendRequest(payload: {
    requesterId: string;
    addresseeId: string;
    requestId: string;
  }): Promise<void> {
    const name = await this.userName(payload.requesterId);
    await this.notify({
      userId: payload.addresseeId,
      type: NotificationType.FRIEND_REQUEST,
      title: 'Заявка в друзья',
      body: name ? `${name} хочет добавить вас в друзья` : 'Новая заявка в друзья',
      data: { requestId: payload.requestId, userId: payload.requesterId },
    });
  }

  @OnEvent('friends.accepted')
  async handleFriendAccepted(payload: {
    addresseeId: string;
    requesterId: string;
    requestId: string;
  }): Promise<void> {
    const name = await this.userName(payload.addresseeId);
    await this.notify({
      userId: payload.requesterId,
      type: NotificationType.FRIEND_ACCEPTED,
      title: 'Заявка принята',
      body: name ? `${name} принял(а) вашу заявку в друзья` : 'Ваша заявка принята',
      data: { requestId: payload.requestId, userId: payload.addresseeId },
    });
  }

  @OnEvent('achievements.unlocked')
  async handleAchievementUnlocked(payload: {
    userId: string;
    achievements: AchievementDef[];
  }): Promise<void> {
    for (const achievement of payload.achievements) {
      await this.notify({
        userId: payload.userId,
        type: NotificationType.ACHIEVEMENT,
        title: 'Достижение открыто',
        body: `${achievement.icon ?? ''} ${achievement.title}: ${achievement.description}`.trim(),
        data: { code: achievement.code },
      });
    }
  }

  @OnEvent('events.joined')
  async handleEventJoined(payload: {
    organizerId: string;
    joinerId: string;
    eventId: string;
    eventTitle: string;
  }): Promise<void> {
    if (payload.organizerId === payload.joinerId) return;
    const name = await this.userName(payload.joinerId);
    await this.notify({
      userId: payload.organizerId,
      type: NotificationType.EVENT_JOINED,
      title: 'Новый участник заплыва',
      body: name
        ? `${name} записался(ась) на «${payload.eventTitle}»`
        : 'На ваш заплыв записались',
      data: { eventId: payload.eventId, userId: payload.joinerId },
    });
  }

  @OnEvent('listings.lead')
  async handleListingLead(payload: {
    sellerId: string;
    buyerId: string;
    listingId: string;
    listingTitle: string;
    leadId: string;
  }): Promise<void> {
    const name = await this.userName(payload.buyerId);
    await this.notify({
      userId: payload.sellerId,
      type: NotificationType.MARKETPLACE,
      title: 'Новая заявка на объявление',
      body: name
        ? `${name} заинтересовался(ась) «${payload.listingTitle}»`
        : `Заявка на «${payload.listingTitle}»`,
      data: {
        listingId: payload.listingId,
        leadId: payload.leadId,
        userId: payload.buyerId,
      },
    });
  }

  @OnEvent('listings.lead_accepted')
  async handleListingLeadAccepted(payload: {
    buyerId: string;
    sellerId: string;
    listingId: string;
    listingTitle: string;
    leadId: string;
  }): Promise<void> {
    const name = await this.userName(payload.sellerId);
    await this.notify({
      userId: payload.buyerId,
      type: NotificationType.MARKETPLACE,
      title: 'Продавец ответил вам',
      body: name
        ? `${name} принял(а) вашу заявку по «${payload.listingTitle}»`
        : `Вашу заявку по «${payload.listingTitle}» приняли`,
      data: {
        listingId: payload.listingId,
        leadId: payload.leadId,
        userId: payload.sellerId,
      },
    });
  }

  private async deliverPush(notification: Notification): Promise<void> {
    if (!this.pushService.enabled) return;
    const devices = await this.devicesRepository.find({
      where: { userId: notification.userId },
    });
    if (devices.length === 0) return;
    await this.pushService.sendToTokens(
      devices.map((d) => d.token),
      {
        title: notification.title,
        body: notification.body,
        data: {
          notificationId: notification.id,
          type: notification.type,
          ...Object.fromEntries(
            Object.entries(notification.data ?? {}).map(([k, v]) => [
              k,
              String(v),
            ]),
          ),
        },
      },
    );
  }

  @OnEvent('events.invited')
  async handleEventInvited(payload: {
    inviterId: string;
    inviteeIds: string[];
    eventId: string;
    eventTitle: string;
  }): Promise<void> {
    const name = await this.userName(payload.inviterId);
    for (const inviteeId of payload.inviteeIds) {
      await this.notify({
        userId: inviteeId,
        type: NotificationType.EVENT_INVITE,
        title: 'Приглашение на заплыв',
        body: name
          ? `${name} приглашает вас на «${payload.eventTitle}»`
          : `Вас приглашают на «${payload.eventTitle}»`,
        data: { eventId: payload.eventId, userId: payload.inviterId },
      });
    }
  }

  private async userName(userId: string): Promise<string | null> {
    const rows: { name: string }[] = await this.dataSource.query(
      `SELECT name FROM users WHERE id = $1`,
      [userId],
    );
    return rows[0]?.name ?? null;
  }
}