import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Channel } from './channel.entity';
import { ChannelMember } from './channel-member.entity';
import { ChannelPost } from './channel-post.entity';
import { ChannelPostLike } from './channel-post-like.entity';
import { ChannelPostComment } from './channel-post-comment.entity';
import { ChannelsService } from './channels.service';
import { ChannelsController } from './channels.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Channel,
      ChannelMember,
      ChannelPost,
      ChannelPostLike,
      ChannelPostComment,
    ]),
  ],
  providers: [ChannelsService],
  controllers: [ChannelsController],
  exports: [ChannelsService],
})
export class ChannelsModule {}
