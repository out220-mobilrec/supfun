import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Repository } from 'typeorm';
import {
  FriendRequest,
  FriendRequestStatus,
} from './friend-request.entity';
import { User } from '../users/user.entity';
import { BlocksService } from '../blocks/blocks.service';

@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(FriendRequest)
    private readonly requestsRepository: Repository<FriendRequest>,
    private readonly eventEmitter: EventEmitter2,
    private readonly blocks: BlocksService,
  ) {}

  async send(me: string, userId: string): Promise<FriendRequest> {
    if (me === userId) {
      throw new BadRequestException('Cannot add yourself');
    }
    if (await this.blocks.blockedEither(me, userId)) {
      throw new ForbiddenException('Interaction is blocked');
    }
    const existing = await this.requestsRepository.findOne({
      where: [
        { requesterId: me, addresseeId: userId },
        { requesterId: userId, addresseeId: me },
      ],
    });
    if (existing) {
      if (existing.status === FriendRequestStatus.PENDING) {
        throw new ConflictException('A friend request already exists');
      }
      if (existing.status === FriendRequestStatus.ACCEPTED) {
        throw new ConflictException('Already friends');
      }
      existing.requesterId = me;
      existing.addresseeId = userId;
      existing.status = FriendRequestStatus.PENDING;
      const resaved = await this.requestsRepository.save(existing);
      this.eventEmitter.emit('friends.request', {
        requesterId: me,
        addresseeId: userId,
        requestId: resaved.id,
      });
      return resaved;
    }
    const request = this.requestsRepository.create({ requesterId: me, addresseeId: userId });
    const saved = await this.requestsRepository.save(request);
    this.eventEmitter.emit('friends.request', {
      requesterId: saved.requesterId,
      addresseeId: saved.addresseeId,
      requestId: saved.id,
    });
    return saved;
  }

  async incoming(me: string): Promise<FriendRequest[]> {
    return this.requestsRepository.find({
      where: { addresseeId: me, status: FriendRequestStatus.PENDING },
      relations: { requester: true },
      order: { createdAt: 'DESC' },
    });
  }

  async outgoing(me: string): Promise<FriendRequest[]> {
    return this.requestsRepository.find({
      where: { requesterId: me, status: FriendRequestStatus.PENDING },
      relations: { addressee: true },
      order: { createdAt: 'DESC' },
    });
  }

  async accept(me: string, requestId: string): Promise<FriendRequest> {
    const request = await this.byIdAndUser(requestId, me, 'Incoming friend request not found');
    request.status = FriendRequestStatus.ACCEPTED;
    const saved = await this.requestsRepository.save(request);
    this.eventEmitter.emit('friends.accepted', {
      addresseeId: saved.addresseeId,
      requesterId: saved.requesterId,
      requestId: saved.id,
    });
    return saved;
  }

  async reject(me: string, requestId: string): Promise<{ ok: boolean }> {
    const request = await this.byIdAndUser(requestId, me, 'Incoming friend request not found');
    request.status = FriendRequestStatus.REJECTED;
    await this.requestsRepository.save(request);
    return { ok: true };
  }

  async cancel(me: string, requestId: string): Promise<{ ok: boolean }> {
    const request = await this.byIdAndUser(requestId, me, 'Outgoing friend request not found');
    await this.requestsRepository.remove(request);
    return { ok: true };
  }

  async list(me: string): Promise<User[]> {
    const rows = await this.requestsRepository.find({
      where: [
        { requesterId: me, status: FriendRequestStatus.ACCEPTED },
        { addresseeId: me, status: FriendRequestStatus.ACCEPTED },
      ],
      relations: { requester: true, addressee: true },
    });
    return rows.map((r) =>
      r.requesterId === me ? r.addressee : r.requester,
    );
  }

  async remove(me: string, friendId: string): Promise<{ ok: boolean }> {
    if (me === friendId) {
      throw new BadRequestException('Cannot remove yourself');
    }
    const rows = await this.requestsRepository.find({
      where: [
        { requesterId: me, addresseeId: friendId },
        { requesterId: friendId, addresseeId: me },
      ],
    });
    if (rows.length === 0) {
      throw new NotFoundException('Not friends');
    }
    await this.requestsRepository.remove(rows);
    return { ok: true };
  }

  async friendIds(me: string): Promise<string[]> {
    const rows = await this.requestsRepository.find({
      where: [
        { requesterId: me, status: FriendRequestStatus.ACCEPTED },
        { addresseeId: me, status: FriendRequestStatus.ACCEPTED },
      ],
    });
    return rows.map((r) => (r.requesterId === me ? r.addresseeId : r.requesterId));
  }

  async areFriends(a: string, b: string): Promise<boolean> {
    const row = await this.requestsRepository.findOne({
      where: [
        { requesterId: a, addresseeId: b, status: FriendRequestStatus.ACCEPTED },
        { requesterId: b, addresseeId: a, status: FriendRequestStatus.ACCEPTED },
      ],
    });
    return Boolean(row);
  }

  private async byIdAndUser(
    id: string,
    userId: string,
    message: string,
  ): Promise<FriendRequest> {
    const request = await this.requestsRepository.findOne({ where: { id } });
    if (!request) {
      throw new NotFoundException(message);
    }
    if (request.addresseeId !== userId && request.requesterId !== userId) {
      throw new NotFoundException(message);
    }
    return request;
  }
}