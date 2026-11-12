import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
}

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

async function resolveUser(
  request: Request,
  jwtService: JwtService,
  configService: ConfigService,
  dataSource: DataSource,
): Promise<boolean> {
  const token = extractToken(request);
  if (!token) {
    throw new UnauthorizedException('Missing access token');
  }
  let payload: JwtPayload;
  try {
    payload = await jwtService.verifyAsync<JwtPayload>(token, {
      secret: configService.get<string>('jwt.secret'),
    });
  } catch {
    throw new UnauthorizedException('Invalid or expired token');
  }
  const rows: { id: string; is_banned: boolean }[] =
    await dataSource.query('SELECT id, is_banned FROM users WHERE id = $1', [
      payload.sub,
    ]);
  if (rows.length === 0) {
    throw new UnauthorizedException('User no longer exists');
  }
  if (rows[0].is_banned) {
    throw new UnauthorizedException('Account is banned');
  }
  (request as any).user = {
    id: payload.sub,
    email: payload.email,
    role: payload.role,
  };
  return true;
}

function extractToken(request: Request): string | null {
  const [type, token] = request.headers.authorization?.split(' ') ?? [];
  return type === 'Bearer' && token ? token : null;
}

function isPublic(context: ExecutionContext, reflector: Reflector): boolean {
  return reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
    context.getHandler(),
    context.getClass(),
  ]) === true;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly dataSource: DataSource,
    private readonly reflector: Reflector,
  ) {}

  canActivate(context: ExecutionContext): Promise<boolean> {
    if (isPublic(context, this.reflector)) {
      return Promise.resolve(true);
    }
    const request = context.switchToHttp().getRequest<Request>();
    return resolveUser(
      request,
      this.jwtService,
      this.configService,
      this.dataSource,
    );
  }
}

@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly dataSource: DataSource,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (isPublic(context, this.reflector)) {
      return true;
    }
    const request = context.switchToHttp().getRequest<Request>();
    try {
      await resolveUser(
        request,
        this.jwtService,
        this.configService,
        this.dataSource,
      );
    } catch {
      (request as any).user = null;
    }
    return true;
  }
}