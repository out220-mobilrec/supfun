import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserBlock } from './user-block.entity';
import { BlocksService } from './blocks.service';
import { BlocksController } from './blocks.controller';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([UserBlock])],
  controllers: [BlocksController],
  providers: [BlocksService],
  exports: [BlocksService],
})
export class BlocksModule {}
