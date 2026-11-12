import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Country } from './country.entity';
import { ReferenceService } from './reference.service';
import { ReferenceController } from './reference.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Country])],
  controllers: [ReferenceController],
  providers: [ReferenceService],
  exports: [ReferenceService],
})
export class ReferenceModule {}
