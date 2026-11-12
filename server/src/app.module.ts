import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

import configuration from './config/configuration';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';

import { UsersModule } from './modules/users/users.module';
import { WaterbodiesModule } from './modules/waterbodies/waterbodies.module';
import { AuthModule } from './modules/auth/auth.module';
import { EventsModule } from './modules/events/events.module';
import { TracksModule } from './modules/tracks/tracks.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { FriendsModule } from './modules/friends/friends.module';
import { BlocksModule } from './modules/blocks/blocks.module';
import { MessagesModule } from './modules/messages/messages.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { MarketplaceModule } from './modules/marketplace/marketplace.module';
import { PostsModule } from './modules/posts/posts.module';
import { FeedModule } from './modules/feed/feed.module';
import { ChannelsModule } from './modules/channels/channels.module';
import { NewsModule } from './modules/news/news.module';
import { GearModule } from './modules/gear/gear.module';
import { RatingsModule } from './modules/ratings/ratings.module';
import { AdminModule } from './modules/admin/admin.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { ReferenceModule } from './modules/reference/reference.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { RoutesModule } from './modules/routes/routes.module';
import { WeatherModule } from './modules/weather/weather.module';
import { HealthController } from './modules/health/health.controller';

@Module({
  imports: [
    EventEmitterModule.forRoot(),
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: 60_000,
          limit: Number(process.env.RATE_LIMIT_PER_MINUTE ?? 500),
        },
      ],
    }),
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: async (config: ConfigService): Promise<TypeOrmModuleOptions> => {
        const dbConfig = config.get<TypeOrmModuleOptions>('database') as TypeOrmModuleOptions;
        // We only ship compiled migrations. Source .ts files exist for
        // editing convenience but loading them from a compiled CJS
        // bundle breaks under newer typeorm which is ESM-only.
        return {
          ...dbConfig,
          autoLoadEntities: true,
          migrations: ['dist/migrations/**/*.js'],
          migrationsRun: process.env.DB_RUN_MIGRATIONS !== 'false',
        };
      },
    }),
    UsersModule,
    WaterbodiesModule,
    AuthModule,
    EventsModule,
    TracksModule,
    GamificationModule,
    FriendsModule,
    BlocksModule,
    MessagesModule,
    NotificationsModule,
    MarketplaceModule,
    PostsModule,
    FeedModule,
    ChannelsModule,
    NewsModule,
    GearModule,
    RatingsModule,
    AdminModule,
    UploadsModule,
    ReferenceModule,
    ReviewsModule,
    RoutesModule,
    WeatherModule,
  ],
  controllers: [HealthController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      // Глобальный JWT guard: все эндпоинты требуют авторизации,
      // кроме помеченных @Public() декоратором
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}