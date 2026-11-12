import { CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import type { Request } from 'express';
import { EntityManager } from 'typeorm';
import { User } from '../../modules/users/user.entity';

/// Forces every protected endpoint behind this guard to require
/// `isEmailVerified = true`. The JWT payload doesn't carry this
/// field (it'd go stale after a fresh verification), so we look it
/// up on every request — it's a single indexed primary-key read.
export class EmailVerifiedGuard implements CanActivate {
  constructor(private readonly em: EntityManager) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request & { user?: { id?: string; isEmailVerified?: boolean } }>();
    const userId = req.user?.id;
    if (!userId) {
      throw new ForbiddenException('Authentication required');
    }
    // Fast path: JWT payload already carries isEmailVerified
    if (req.user?.isEmailVerified === true) {
      return true;
    }
    const user = await this.em.findOne(User, {
      where: { id: userId },
      select: ['id', 'isEmailVerified', 'email'],
    });
    if (!user) {
      throw new ForbiddenException('User not found');
    }
    if (!user.isEmailVerified) {
      throw new ForbiddenException({
        message: 'Email не подтверждён. Проверьте почту и подтвердите код.',
        code: 'EMAIL_NOT_VERIFIED',
        email: user.email,
      });
    }
    return true;
  }
}