import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { UnauthorizedException } from '@nestjs/common';
import { MessagesService } from './messages.service';
import { Message, MessageStatus } from './message.entity';
import { SendMessageDto } from './dto/messages.dto';

interface ChatSocket extends Socket {
  data: { userId?: string };
}

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: '*', credentials: true },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  private readonly server: Server;

  private readonly online = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly messagesService: MessagesService,
  ) {}

  async handleConnection(client: ChatSocket): Promise<void> {
    try {
      const token =
        (client.handshake.auth as { token?: string } | undefined)?.token ??
        (client.handshake.query?.token as string | undefined);
      if (!token) {
        throw new UnauthorizedException('Missing token');
      }
      const payload = await this.jwtService.verifyAsync<{ sub: string }>(token, {
        secret: this.configService.get<string>('jwt.secret'),
      });
      client.data.userId = payload.sub;
      await client.join('presence');
      await client.join(`user:${payload.sub}`);
      const sockets = this.online.get(payload.sub) ?? new Set<string>();
      sockets.add(client.id);
      this.online.set(payload.sub, sockets);
      if (sockets.size === 1) {
        this.server.to('presence').emit('presence:change', {
          userId: payload.sub,
          online: true,
          at: new Date().toISOString(),
        });
      }
    } catch {
      client.disconnect();
    }
  }

  async handleDisconnect(client: ChatSocket): Promise<void> {
    const userId = client.data.userId;
    if (!userId) return;
    const sockets = this.online.get(userId);
    if (sockets) {
      sockets.delete(client.id);
      if (sockets.size === 0) {
        this.online.delete(userId);
        this.server.to('presence').emit('presence:change', {
          userId,
          online: false,
          at: new Date().toISOString(),
        });
      }
    }
  }

  @SubscribeMessage('presence:list')
  presenceList(@ConnectedSocket() client: ChatSocket) {
    return {
      ok: true,
      online: [...this.online.keys()],
      self: client.data.userId,
    };
  }

  pushToUser(userId: string, event: string, payload: unknown): void {
    this.server.to(`user:${userId}`).emit(event, payload);
  }

  @SubscribeMessage('conversation:join')
  async joinConversation(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string },
  ) {
    const me = client.data.userId!;
    await this.messagesService.findOne(body.conversationId, me);
    await client.join(`conv:${body.conversationId}`);
    return { ok: true };
  }

  @SubscribeMessage('conversation:leave')
  async leaveConversation(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string },
  ) {
    await client.leave(`conv:${body.conversationId}`);
    return { ok: true };
  }

  @SubscribeMessage('chat:send')
  async sendMessage(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string; message: SendMessageDto },
  ) {
    const me = client.data.userId!;
    const saved = await this.messagesService.send(
      body.conversationId,
      me,
      body.message,
    );
    const message = await this.messagesService.findOneMessage(
      body.conversationId,
      me,
      saved.id,
    );
    client
      .to(`conv:${body.conversationId}`)
      .emit('chat:new', { message, conversationId: body.conversationId });
    return { ok: true, message };
  }

  @SubscribeMessage('chat:delivered')
  async markDelivered(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string; messageId: string },
  ) {
    const me = client.data.userId!;
    const message = await this.messagesService.setMessageStatus(
      body.conversationId,
      me,
      body.messageId,
      MessageStatus.DELIVERED,
    );
    client
      .to(`conv:${body.conversationId}`)
      .emit('chat:status', {
        conversationId: body.conversationId,
        messageId: message.id,
        status: message.status,
      });
    return { ok: true };
  }

  @SubscribeMessage('chat:read')
  async markRead(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string },
  ) {
    const me = client.data.userId!;
    await this.messagesService.markRead(body.conversationId, me);
    client
      .to(`conv:${body.conversationId}`)
      .emit('chat:status', {
        conversationId: body.conversationId,
        userId: me,
        status: MessageStatus.READ,
      });
    return { ok: true };
  }

  @SubscribeMessage('chat:typing')
  typing(
    @ConnectedSocket() client: ChatSocket,
    @MessageBody() body: { conversationId: string; isTyping: boolean },
  ) {
    const me = client.data.userId!;
    client
      .to(`conv:${body.conversationId}`)
      .emit('chat:typing', {
        conversationId: body.conversationId,
        userId: me,
        isTyping: body.isTyping,
      });
    return { ok: true };
  }
}