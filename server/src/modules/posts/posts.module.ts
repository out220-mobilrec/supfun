import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Post } from './post.entity';
import { PostLike } from './post-like.entity';
import { PostComment } from './post-comment.entity';
import { PostsService } from './posts.service';
import { PostsController } from './posts.controller';
import { FriendsModule } from '../friends/friends.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Post, PostLike, PostComment]),
    FriendsModule,
  ],
  controllers: [PostsController],
  providers: [PostsService],
  exports: [PostsService],
})
export class PostsModule {}
