import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { UserBlock } from './user-block.entity';
import { User } from '../users/user.entity';

@Injectable()
export class BlocksService {
  constructor(
    @InjectRepository(UserBlock)
    private readonly repository: Repository<UserBlock>,
    private readonly dataSource: DataSource,
  ) {}

  async block(me: string, userId: string): Promise<{ ok: boolean }> {
    if (me === userId) {
      throw new BadRequestException('Cannot block yourself');
    }
    const existing = await this.repository.findOne({
      where: { blockerId: me, blockedId: userId },
    });
    if (!existing) {
      await this.repository.save(
        this.repository.create({ blockerId: me, blockedId: userId }),
      );
    }
    await this.dataSource.query(
      `DELETE FROM friend_requests
       WHERE (requester_id = $1 AND addressee_id = $2)
          OR (requester_id = $2 AND addressee_id = $1)`,
      [me, userId],
    );
    return { ok: true };
  }

  async unblock(me: string, userId: string): Promise<{ ok: boolean }> {
    const result = await this.repository.delete({
      blockerId: me,
      blockedId: userId,
    });
    if (!result.affected) {
      throw new NotFoundException('Block not found');
    }
    return { ok: true };
  }

  async list(me: string): Promise<User[]> {
    const rows = await this.repository.find({
      where: { blockerId: me },
      relations: { blocked: true },
      order: { createdAt: 'DESC' },
    });
    return rows.map((r) => r.blocked);
  }

  async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    const row = await this.repository.findOne({
      where: { blockerId, blockedId },
    });
    return Boolean(row);
  }

  async blockedEither(a: string, b: string): Promise<boolean> {
    const row = await this.repository.findOne({
      where: [
        { blockerId: a, blockedId: b },
        { blockerId: b, blockedId: a },
      ],
    });
    return Boolean(row);
  }

  async blockedIds(me: string): Promise<string[]> {
    const rows = await this.repository.find({
      where: { blockerId: me },
      select: { blockedId: true },
    });
    return rows.map((r) => r.blockedId);
  }

  async hiddenIds(me: string): Promise<string[]> {
    const [outgoing, incoming] = await Promise.all([
      this.repository.find({
        where: { blockerId: me },
        select: { blockedId: true },
      }),
      this.repository.find({
        where: { blockedId: me },
        select: { blockerId: true },
      }),
    ]);
    return Array.from(
      new Set([
        ...outgoing.map((r) => r.blockedId),
        ...incoming.map((r) => r.blockerId),
      ]),
    );
  }
}
