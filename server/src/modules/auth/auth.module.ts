import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { AuthToken } from './auth-token.entity';
import { MailService } from './mail.service';
import { UsersModule } from '../users/users.module';

@Global()
@Module({
  imports: [
    UsersModule,
    TypeOrmModule.forFeature([AuthToken]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('jwt.secret'),
        signOptions: {
          expiresIn: config.get<string>('jwt.expiresIn') as never,
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, MailService],
  exports: [JwtModule, AuthService, MailService],
})
export class AuthModule {}