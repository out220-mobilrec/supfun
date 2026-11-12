import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GearItem } from './gear-item.entity';
import { GearService } from './gear.service';
import { GearController } from './gear.controller';
import { BlocksModule } from '../blocks/blocks.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([GearItem]),
    BlocksModule,
  ],
  controllers: [GearController],
  providers: [GearService],
  exports: [GearService],
})
export class GearModule {}