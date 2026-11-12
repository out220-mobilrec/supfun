import {
  Body,
  Controller,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { AuthService, AuthResult, MessageResult } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LogoutDto,
  RefreshTokenDto,
  ResetPasswordDto,
  VerifyEmailDto,
} from './dto/account.dto';
import { JwtAuthGuard, Public } from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';

/// Audit context — pulled from the inbound HTTP request so every
/// auth-related row in `auth_audit` carries IP + user-agent.
function ctxFrom(req: Request) {
  const fwd = (req.headers['x-forwarded-for'] as string | undefined)?.split(',')[0]?.trim();
  const ip = fwd || req.ip || req.socket?.remoteAddress;
  const userAgent = (req.headers['user-agent'] as string | undefined) ?? null;
  return { ip, userAgent };
}

/// Tight rate limits for auth-sensitive endpoints. Override by env:
///   AUTH_RATE_PER_MIN — limit (default 5)
///   AUTH_RATE_WINDOW  — window in seconds (default 60)
const AUTH_RATE_LIMIT = Number(process.env.AUTH_RATE_PER_MIN ?? 5);
const AUTH_RATE_WINDOW = Number(process.env.AUTH_RATE_WINDOW ?? 60);

const AuthThrottle = () =>
  Throttle({ default: { limit: AUTH_RATE_LIMIT, ttl: AUTH_RATE_WINDOW * 1000 } });

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @AuthThrottle()
  @Post('register')
  register(
    @Body() dto: RegisterDto,
    @Req() req: Request,
  ): Promise<{ message: string; devCode?: string }> {
    return this.authService.register(dto, ctxFrom(req));
  }

  @Public()
  @AuthThrottle()
  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request): Promise<AuthResult> {
    return this.authService.login(dto, ctxFrom(req));
  }

  @Public()
  @Post('refresh')
  refresh(
    @Body() dto: RefreshTokenDto,
    @Req() req: Request,
  ): Promise<AuthResult> {
    return this.authService.refresh(dto.refreshToken, ctxFrom(req));
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  logout(@Body() dto: LogoutDto, @Req() req: Request): Promise<MessageResult> {
    return this.authService.logout(dto.refreshToken, ctxFrom(req));
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout-all')
  logoutAll(
    @CurrentUser() current: AuthUser,
    @Req() req: Request,
  ): Promise<MessageResult> {
    return this.authService.logoutAll(current.id, ctxFrom(req));
  }

  @UseGuards(JwtAuthGuard)
  @Post('resend-verification')
  resendVerification(
    @CurrentUser() current: AuthUser,
    @Req() req: Request,
  ): Promise<MessageResult> {
    return this.authService.resendVerification(current.id, ctxFrom(req));
  }

  @Public()
  @AuthThrottle()
  @Post('verify-email')
  verifyEmail(
    @Body() dto: VerifyEmailDto,
    @Req() req: Request,
  ): Promise<AuthResult> {
    return this.authService.verifyWithCredentials(
      dto.email,
      dto.code,
      ctxFrom(req),
    );
  }

  @Public()
  @AuthThrottle()
  @Post('forgot-password')
  forgotPassword(
    @Body() dto: ForgotPasswordDto,
    @Req() req: Request,
  ): Promise<MessageResult> {
    return this.authService.forgotPassword(dto.email, ctxFrom(req));
  }

  @Public()
  @AuthThrottle()
  @Post('reset-password')
  resetPassword(
    @Body() dto: ResetPasswordDto,
    @Req() req: Request,
  ): Promise<MessageResult> {
    return this.authService.resetPassword(
      dto.email,
      dto.code,
      dto.password,
      ctxFrom(req),
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('change-password')
  changePassword(
    @CurrentUser() current: AuthUser,
    @Body() dto: ChangePasswordDto,
    @Req() req: Request,
  ): Promise<AuthResult> {
    return this.authService.changePassword(current.id, dto, ctxFrom(req));
  }
}
