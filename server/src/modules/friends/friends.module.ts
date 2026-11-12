import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FriendRequest } from './friend-request.entity';
import { FriendsService } from './friends.service';
import { FriendsController } from './friends.controller';

@Module({
  imports: [TypeOrmModule.forFeature([FriendRequest])],
  controllers: [FriendsController],
  providers: [FriendsService],
  exports: [FriendsService],
})
export class FriendsModule {}