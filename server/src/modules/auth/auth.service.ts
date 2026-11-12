import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, LessThan, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'crypto';
import { Request } from 'express';
import { UsersService } from '../users/users.service';
import { User } from '../users/user.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import {
  ChangePasswordDto,
  ResetPasswordDto,
} from './dto/account.dto';
import { AuthToken, AuthTokenType } from './auth-token.entity';
import { MailService } from './mail.service';

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export interface MessageResult {
  ok: boolean;
  /// Short-lived verification code we send by email. Only returned in
/// non-production environments for easier testing.
  devCode?: string;
}

/// TTL settings — kept short on purpose so credentials that get
/// accidentally pasted into logs don't live forever.
const VERIFY_TTL_MS = 15 * 60 * 1000; // 15 min
const RESET_TTL_MS = 15 * 60 * 1000; // 15 min
const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
/// Brute-force threshold: failed attempts per code before we revoke.
const MAX_CODE_ATTEMPTS = 10;

/// Plain data we attach to audit rows. Stored in `auth_audit`.
interface AuditContext {
  ip?: string | null;
  userAgent?: string | null;
  userId?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly mail: MailService,
    private readonly dataSource: DataSource,
    @InjectRepository(AuthToken)
    private readonly tokens: Repository<AuthToken>,
  ) {}

  private async audit(
    userId: string | null,
    event: string,
    ctx: AuditContext = {},
  ): Promise<void> {
    try {
      await this.dataSource.query(
        `INSERT INTO auth_audit (id, user_id, event, ip, user_agent, created_at)
         VALUES (gen_random_uuid(), $1, $2, $3::inet, $4, now())`,
        [userId, event, ctx.ip ?? null, ctx.userAgent ?? null],
      );
    } catch {
      // audit must never block the auth flow
    }
  }

  private async findUserByEmail(email: string): Promise<User | null> {
    return this.usersService.findByEmail(email);
  }

  async register(
    dto: RegisterDto,
    ctx: AuditContext = {},
  ): Promise<{ message: string; devCode?: string }> {
    const existing = await this.findUserByEmail(dto.email);
    if (existing) {
      // Always behave like a new user (no enumeration).
      await this.audit(null, 'register_attempt_existing', ctx);
      return { message: 'Если email свободен, на него отправлен код.' };
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.usersService.create({
      email: dto.email,
      name: dto.name,
      phone: dto.phone ?? null,
      city: dto.city ?? null,
      passwordHash,
    });
    await this.sendVerificationCode(user, ctx);
    await this.audit(user.id, 'register_success', ctx);
    return { message: 'Код подтверждения отправлен на ваш email.' };
  }

  async login(
    dto: LoginDto,
    ctx: AuditContext = {},
  ): Promise<AuthResult> {
    const user = await this.usersService.findByEmailWithPassword(dto.email);
    if (!user) {
      await this.audit(null, 'login_failed_no_user', ctx);
      // Same message + delay for both cases — no enumeration.
      await bcrypt.compare(dto.password, '$2b$10$invalidsaltinvalidsaltinvalidsa');
      throw new UnauthorizedException('Invalid email or password');
    }
    const passwordOk = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordOk) {
      await this.audit(user.id, 'login_failed_wrong_password', ctx);
      throw new UnauthorizedException('Invalid email or password');
    }
    if (user.isBanned) {
      await this.audit(user.id, 'login_banned', ctx);
      throw new ForbiddenException('Account is banned. Contact support.');
    }
    if (!user.isEmailVerified) {
      await this.audit(user.id, 'login_unverified', ctx);
      throw new ForbiddenException({
        message: 'Email не подтверждён. Проверьте почту и подтвердите код.',
        code: 'EMAIL_NOT_VERIFIED',
        email: user.email,
      });
    }
    const safe = await this.usersService.findById(user.id);
    const tokens = await this.issueTokens(safe);
    await this.audit(user.id, 'login_success', ctx);
    return tokens;
  }

  /// Used by the verify-email UI to "I lost the email, send me a new code".
  /// Requires JWT — i.e. the user must already be authenticated in some way.
  async resendVerification(
    userId: string,
    ctx: AuditContext = {},
  ): Promise<MessageResult> {
    const user = await this.usersService.findById(userId);
    if (user.isEmailVerified) {
      throw new BadRequestException('Email is already verified');
    }
    await this.sendVerificationCode(user, ctx);
    return { ok: true };
  }

  /// Send a fresh 6-digit verification code to the user's email.
  /// Returns the plain code to the caller in non-production environments.
  async sendVerificationCode(
    user: User,
    ctx: AuditContext = {},
  ): Promise<{ devCode?: string }> {
    // Revoke any existing verification codes for this user so only
    // the most recent code is valid.
    await this.tokens.delete({
      userId: user.id,
      type: AuthTokenType.EMAIL_VERIFY,
    });
    const code = await this.createCode(
      user.id,
      AuthTokenType.EMAIL_VERIFY,
      VERIFY_TTL_MS,
    );
    const link = `${this.frontendUrl()}/verify-email?email=${
      encodeURIComponent(user.email)
    }&code=${code}`;
    await this.mail.send(
      user.email,
      'Подтверждение email — SUP FUN',
      `Здравствуйте, ${user.name}!

Ваш код подтверждения: ${code}

Либо перейдите по ссылке (действует ${Math.round(
        VERIFY_TTL_MS / 60000,
      )} мин):
${link}

Если вы не регистрировались — проигнорируйте письмо.`,
    );
    await this.audit(user.id, 'email_verify_code_sent', ctx);
    if (this.configService.get<string>('nodeEnv') !== 'production') {
      return { devCode: code };
    }
    return {};
  }

  /// Verify using email + code (POST). Confirms ownership of the
  /// mailbox and, on success, issues an auth pair so the user is
  /// immediately signed in.
  async verifyWithCredentials(
    email: string,
    code: string,
    ctx: AuditContext = {},
  ): Promise<AuthResult> {
    const user = await this.findUserByEmail(email);
    if (!user) {
      await this.audit(null, 'verify_unknown_email', ctx);
      throw new BadRequestException('Invalid or expired code');
    }
    const row = await this.findCode(
      code,
      AuthTokenType.EMAIL_VERIFY,
      user.id,
    );
    if (user.isEmailVerified) {
      await this.audit(user.id, 'verify_already_verified', ctx);
      throw new BadRequestException('Email уже подтверждён');
    }
    await this.usersService.update(user.id, { isEmailVerified: true });
    await this.tokens.delete({
      userId: user.id,
      type: AuthTokenType.EMAIL_VERIFY,
    });
    await this.audit(user.id, 'email_verified', ctx);
    const safe = await this.usersService.findById(user.id);
    return this.issueTokens(safe);
  }

  /// Reset-password request: user submits email, we send a code.
  /// Always responds with the same message regardless of email
  /// existence — no enumeration.
  async forgotPassword(
    email: string,
    ctx: AuditContext = {},
  ): Promise<MessageResult> {
    const user = await this.findUserByEmail(email);
    if (user) {
      await this.sendResetCode(user, ctx);
    } else {
      await this.audit(null, 'reset_unknown_email', ctx);
    }
    // Always 1 second response time to avoid timing-based enumeration.
    await new Promise((r) => setTimeout(r, 50));
    return { ok: true };
  }

  async sendResetCode(
    user: User,
    ctx: AuditContext = {},
  ): Promise<{ devCode?: string }> {
    await this.tokens.delete({
      userId: user.id,
      type: AuthTokenType.PASSWORD_RESET,
    });
    const code = await this.createCode(
      user.id,
      AuthTokenType.PASSWORD_RESET,
      RESET_TTL_MS,
    );
    await this.mail.send(
      user.email,
      'Сброс пароля — SUP FUN',
      `Здравствуйте, ${user.name}!

Ваш код для сброса пароля: ${code}

Код действует ${Math.round(RESET_TTL_MS / 60000)} мин.
Если вы не запрашивали сброс — проигнорируйте письмо.`,
    );
    await this.audit(user.id, 'reset_code_sent', ctx);
    if (this.configService.get<string>('nodeEnv') !== 'production') {
      return { devCode: code };
    }
    return {};
  }

  /// Confirm new password using email + code.
  async resetPassword(
    email: string,
    code: string,
    newPassword: string,
    ctx: AuditContext = {},
  ): Promise<MessageResult> {
    const user = await this.findUserByEmail(email);
    if (!user) {
      throw new BadRequestException('Invalid or expired code');
    }
    await this.findCode(code, AuthTokenType.PASSWORD_RESET, user.id);
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.usersService.update(user.id, { passwordHash });
    await this.tokens.delete({
      userId: user.id,
      type: AuthTokenType.PASSWORD_RESET,
    });
    // Invalidate all refresh tokens to log every other device out.
    await this.revokeRefreshTokens(user.id);
    await this.audit(user.id, 'password_reset_success', ctx);
    return { ok: true };
  }

  async refresh(
    refreshToken: string,
    ctx: AuditContext = {},
  ): Promise<AuthResult> {
    const row = await this.findCode(
      refreshToken,
      AuthTokenType.REFRESH,
    );
    row.usedAt = new Date();
    await this.tokens.save(row);
    const user = await this.usersService.findById(row.userId);
    if (user.isBanned) {
      await this.audit(user.id, 'refresh_banned', ctx);
      throw new ForbiddenException('Account is banned. Contact support.');
    }
    const tokens = await this.issueTokens(user);
    await this.audit(user.id, 'token_refresh', ctx);
    return tokens;
  }

  async logout(refreshToken: string, ctx: AuditContext = {}): Promise<MessageResult> {
    await this.tokens.delete({
      tokenHash: this.hash(refreshToken),
      type: AuthTokenType.REFRESH,
    });
    if (ctx.userId) await this.audit(ctx.userId, 'logout', ctx);
    return { ok: true };
  }

  async logoutAll(userId: string, ctx: AuditContext = {}): Promise<MessageResult> {
    await this.revokeRefreshTokens(userId);
    await this.audit(userId, 'logout_all', ctx);
    return { ok: true };
  }

  async changePassword(
    userId: string,
    dto: ChangePasswordDto,
    ctx: AuditContext = {},
  ): Promise<AuthResult> {
    const user = await this.usersService.findByEmailWithPassword(
      (await this.usersService.findById(userId)).email,
    );
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    const ok = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!ok) {
      await this.audit(userId, 'change_password_wrong_current', ctx);
      throw new BadRequestException('Current password is incorrect');
    }
    const passwordHash = await bcrypt.hash(dto.newPassword, 10);
    await this.usersService.update(userId, { passwordHash });
    await this.revokeRefreshTokens(userId);
    await this.audit(userId, 'password_changed', ctx);
    const safe = await this.usersService.findById(userId);
    return this.issueTokens(safe);
  }

  /// Internal: create a new short code, persist hash + TTL.
  private async createCode(
    userId: string,
    type: AuthTokenType,
    ttlMs: number,
  ): Promise<string> {
    // 6 random digits — we re-roll if the value starts with 0 and the
    // system treats it as an int. Format as 6-char zero-padded string.
    const code = String(randomBytes(4).readUInt32BE(0) % 1_000_000)
      .padStart(6, '0');
    await this.tokens.save(
      this.tokens.create({
        userId,
        type,
        tokenHash: this.hash(code),
        expiresAt: new Date(Date.now() + ttlMs),
        usedAt: null,
        attemptCount: 0,
      }),
    );
    return code;
  }

  /// Internal: lookup a code by its plaintext, throttling brute-force.
  private async findCode(
    rawCode: string,
    type: AuthTokenType,
    userId?: string,
  ): Promise<AuthToken> {
    const where: Record<string, unknown> = {
      tokenHash: this.hash(rawCode),
      type,
    };
    if (userId) where.userId = userId;
    const row = await this.tokens.findOne({ where });
    if (!row || row.usedAt || row.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('Invalid or expired code');
    }
    if (row.attemptCount >= MAX_CODE_ATTEMPTS) {
      await this.tokens.delete({ id: row.id });
      throw new ForbiddenException(
        'Слишком много неверных попыток. Запросите новый код.',
      );
    }
    return row;
  }

  /// Internal: record a wrong attempt. Caller must throw afterwards.
  async recordFailedAttempt(row: AuthToken): Promise<void> {
    row.attemptCount += 1;
    await this.tokens.save(row);
    if (row.attemptCount >= MAX_CODE_ATTEMPTS) {
      // revoke whole family on threshold breach
      await this.tokens.delete({
        userId: row.userId,
        type: row.type,
      });
    }
  }

  private async issueTokens(user: User): Promise<AuthResult> {
    const accessToken = this.sign(user);
    // For refresh tokens we keep the random URL-safe string approach
    // (64 bytes) because they sit in HttpOnly cookie / storage, not on
    // paper — and 6 digits of entropy is way too low for a 30-day secret.
    const refreshToken = await this.createLongRefreshToken(
      user.id,
      REFRESH_TTL_MS,
    );
    return { accessToken, refreshToken, user };
  }

  private async createLongRefreshToken(
    userId: string,
    ttlMs: number,
  ): Promise<string> {
    const raw = randomBytes(48).toString('base64url');
    await this.tokens.save(
      this.tokens.create({
        userId,
        type: AuthTokenType.REFRESH,
        tokenHash: this.hash(raw),
        expiresAt: new Date(Date.now() + ttlMs),
        usedAt: null,
        attemptCount: 0,
      }),
    );
    return raw;
  }

  private sign(user: User): string {
    return this.jwtService.sign(
      { email: user.email, role: user.role },
      {
        secret: this.configService.get<string>('jwt.secret'),
        expiresIn: this.configService.get<string>('jwt.expiresIn') as never,
        subject: user.id,
      },
    );
  }

  private async revokeRefreshTokens(userId: string): Promise<void> {
    await this.tokens.delete({ userId, type: AuthTokenType.REFRESH });
  }

  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private frontendUrl(): string {
    return this.configService.get<string>('frontendUrl') ?? 'http://localhost:5173';
  }

  async cleanupExpiredTokens(): Promise<number> {
    const res = await this.tokens.delete({ expiresAt: LessThan(new Date()) });
    return res.affected ?? 0;
  }
}
