import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { In, Repository } from 'typeorm';
import { Conversation, ConversationType } from './conversation.entity';
import { ConversationParticipant } from './conversation-participant.entity';
import { Message, MessageStatus, MessageType } from './message.entity';
import {
  CreateConversationDto,
  DirectConversationDto,
  SendMessageDto,
} from './dto/messages.dto';

export interface ConversationSummary {
  id: string;
  type: ConversationType;
  title: string | null;
  eventId: string | null;
  lastMessageAt: Date | null;
  lastMessage: Message | null;
  unreadCount: number;
  participants: ConversationParticipant[];
}

@Injectable()
export class MessagesService {
  constructor(
    @InjectRepository(Conversation)
    private readonly conversationsRepository: Repository<Conversation>,
    @InjectRepository(ConversationParticipant)
    private readonly participantsRepository: Repository<ConversationParticipant>,
    @InjectRepository(Message)
    private readonly messagesRepository: Repository<Message>,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async findOrCreateDirect(me: string, dto: DirectConversationDto): Promise<Conversation> {
    if (me === dto.userId) {
      throw new BadRequestException('Cannot message yourself');
    }
    const existing = await this.findDirect(me, dto.userId);
    if (existing) return existing;
    return this.create({ type: ConversationType.DIRECT, memberIds: [me, dto.userId] }, me);
  }

  async create(dto: CreateConversationDto, me: string): Promise<Conversation> {
    if (dto.type === ConversationType.EVENT && !dto.eventId) {
      throw new BadRequestException('eventId is required for event conversations');
    }
    const memberIds = [...new Set([me, ...(dto.memberIds ?? [])])];
    const conversation = this.conversationsRepository.create({
      type: dto.type,
      title: dto.title ?? null,
      eventId: dto.eventId ?? null,
      participants: memberIds.map((userId) =>
        this.participantsRepository.create({ userId }),
      ),
    });
    const saved = await this.conversationsRepository.save(conversation);
    return this.findOne(saved.id, me);
  }

  async listMine(me: string): Promise<ConversationSummary[]> {
    const participants = await this.participantsRepository.find({
      where: { userId: me },
    });
    const ids = participants.map((p) => p.conversationId);
    if (ids.length === 0) return [];

    const conversations = await this.conversationsRepository.find({
      where: { id: In(ids) },
      order: { lastMessageAt: 'DESC' },
    });

    const summaries: ConversationSummary[] = [];
    for (const conversation of conversations) {
      const convParticipants = await this.participantsRepository.find({
        where: { conversationId: conversation.id },
        relations: { user: true },
      });
      const lastMessage = await this.messagesRepository.findOne({
        where: { conversationId: conversation.id },
        order: { createdAt: 'DESC' },
      });
      const lastRead = participants.find(
        (p) => p.conversationId === conversation.id,
      )?.lastReadAt;
      const unread = lastMessage && (!lastRead || lastMessage.createdAt > lastRead) ? 1 : 0;

      summaries.push({
        id: conversation.id,
        type: conversation.type,
        title: conversation.title,
        eventId: conversation.eventId,
        lastMessageAt: conversation.lastMessageAt,
        lastMessage: lastMessage ?? null,
        unreadCount: unread,
        participants: convParticipants,
      });
    }
    return summaries;
  }

  async findOne(id: string, me: string): Promise<Conversation> {
    await this.assertParticipant(id, me);
    const conversation = await this.conversationsRepository.findOne({
      where: { id },
    });
    if (!conversation) {
      throw new NotFoundException(`Conversation ${id} not found`);
    }
    (conversation as any).participants = await this.participantsRepository.find({
      where: { conversationId: id },
      relations: { user: true },
    });
    return conversation;
  }

  async messages(
    id: string,
    me: string,
    before?: string,
    limit = 50,
  ): Promise<Message[]> {
    await this.assertParticipant(id, me);
    const qb = this.messagesRepository
      .createQueryBuilder('message')
      .leftJoinAndSelect('message.sender', 'sender')
      .leftJoinAndSelect('message.replyTo', 'replyTo')
      .where('message.conversationId = :id', { id })
      .orderBy('message.createdAt', 'DESC')
      .take(Math.min(limit, 100));
    if (before) {
      qb.andWhere('message.createdAt < :before', { before: new Date(before) });
    }
    const rows = await qb.getMany();
    return rows.reverse();
  }

  async send(
    id: string,
    me: string,
    dto: SendMessageDto,
  ): Promise<Message> {
    await this.assertParticipant(id, me);
    const type = dto.type ?? MessageType.TEXT;
    if (type === MessageType.TEXT && !dto.content) {
      throw new BadRequestException('content is required for text messages');
    }
    if (type === MessageType.LOCATION && (dto.latitude == null || dto.longitude == null)) {
      throw new BadRequestException('latitude/longitude are required for location messages');
    }

    const message = this.messagesRepository.create({
      conversationId: id,
      senderId: me,
      type,
      content: dto.content ?? null,
      nonce: dto.nonce ?? null,
      latitude: dto.latitude ?? null,
      longitude: dto.longitude ?? null,
      replyToId: dto.replyToId ?? null,
    });
    const saved = await this.messagesRepository.save(message);

    const conversation = await this.conversationsRepository.findOne({ where: { id } });
    if (conversation) {
      conversation.lastMessageAt = saved.createdAt;
      await this.conversationsRepository.save(conversation);
    }

    await this.participantsRepository
      .createQueryBuilder()
      .update(ConversationParticipant)
      .set({ lastReadAt: saved.createdAt })
      .where('conversationId = :id AND userId = :me', { id, me })
      .execute();

    this.eventEmitter.emit('messages.sent', {
      senderId: me,
      conversationId: id,
      content: saved.content,
    });
    return saved;
  }

  async markRead(id: string, me: string): Promise<{ ok: boolean }> {
    await this.assertParticipant(id, me);
    await this.participantsRepository
      .createQueryBuilder()
      .update(ConversationParticipant)
      .set({ lastReadAt: new Date() })
      .where('conversationId = :id AND userId = :me', { id, me })
      .execute();
    await this.messagesRepository
      .createQueryBuilder()
      .update(Message)
      .set({ status: MessageStatus.READ })
      .where('conversationId = :id AND status != :status', {
        id,
        status: MessageStatus.READ,
      })
      .execute();
    return { ok: true };
  }

  async setMessageStatus(
    id: string,
    me: string,
    messageId: string,
    status: MessageStatus,
  ): Promise<Message> {
    await this.assertParticipant(id, me);
    const message = await this.messagesRepository.findOne({
      where: { id: messageId, conversationId: id },
    });
    if (!message) {
      throw new NotFoundException(`Message ${messageId} not found`);
    }
    message.status = status;
    return this.messagesRepository.save(message);
  }

  async findOneMessage(id: string, me: string, messageId: string): Promise<Message> {
    await this.assertParticipant(id, me);
    const message = await this.messagesRepository.findOne({
      where: { id: messageId, conversationId: id },
      relations: { sender: true, replyTo: true },
    });
    if (!message) {
      throw new NotFoundException(`Message ${messageId} not found`);
    }
    return message;
  }

  async participants(id: string, me: string): Promise<ConversationParticipant[]> {
    await this.assertParticipant(id, me);
    return this.participantsRepository.find({
      where: { conversationId: id },
      relations: { user: true },
    });
  }

  private async findDirect(a: string, b: string): Promise<Conversation | null> {
    const rows = await this.participantsRepository.find({
      where: { userId: In([a, b]) },
    });
    const counts = new Map<string, number>();
    for (const row of rows) {
      counts.set(row.conversationId, (counts.get(row.conversationId) ?? 0) + 1);
    }
    for (const [conversationId, count] of counts) {
      if (count === 2) {
        const conversation = await this.conversationsRepository.findOne({
          where: { id: conversationId, type: ConversationType.DIRECT },
        });
        if (conversation) return conversation;
      }
    }
    return null;
  }

  private async assertParticipant(id: string, me: string): Promise<void> {
    const count = await this.participantsRepository.count({
      where: { conversationId: id, userId: me },
    });
    if (count === 0) {
      throw new ForbiddenException('Not a member of this conversation');
    }
  }
}