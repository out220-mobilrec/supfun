import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { GearItem } from './gear-item.entity';
import { CreateGearDto, UpdateGearDto } from './dto/gear.dto';
import { BlocksService } from '../blocks/blocks.service';

export interface Paginated<T> {
  items: T[];
  hasMore: boolean;
}

@Injectable()
export class GearService {
  constructor(
    @InjectRepository(GearItem)
    private readonly gear: Repository<GearItem>,
    private readonly blocks: BlocksService,
  ) {}

  async listMine(me: string): Promise<GearItem[]> {
    return this.gear.find({
      where: { userId: me },
      order: { createdAt: 'DESC' },
    });
  }

  async listForUser(
    actorId: string,
    targetId: string,
    options: { limit?: number; offset?: number } = {},
  ): Promise<Paginated<GearItem>> {
    if (actorId !== targetId) {
      const hidden = await this.blocks.hiddenIds(actorId);
      if (hidden.includes(targetId)) {
        throw new NotFoundException('Gear not found');
      }
    }
    const limit = Math.min(Math.max(options.limit ?? 50, 1), 100);
    const offset = Math.max(options.offset ?? 0, 0);
    const rows = await this.gear.find({
      where: { userId: targetId },
      order: { createdAt: 'DESC' },
      take: limit + 1,
      skip: offset,
    });
    const hasMore = rows.length > limit;
    return { items: rows.slice(0, limit), hasMore };
  }

  async create(me: string, dto: CreateGearDto): Promise<GearItem> {
    const item = this.gear.create({
      userId: me,
      category: dto.category,
      brand: dto.brand ?? null,
      model: dto.model ?? null,
      lengthCm: dto.lengthCm ?? null,
      widthCm: dto.widthCm ?? null,
      volumeL: dto.volumeL ?? null,
      weightKg: dto.weightKg ?? null,
      material: dto.material ?? null,
      notes: dto.notes ?? null,
    });
    return this.gear.save(item);
  }

  async update(
    me: string,
    id: string,
    dto: UpdateGearDto,
  ): Promise<GearItem> {
    const item = await this.requireOwned(me, id);
    Object.assign(item, {
      category: dto.category ?? item.category,
      brand: dto.brand !== undefined ? dto.brand : item.brand,
      model: dto.model !== undefined ? dto.model : item.model,
      lengthCm: dto.lengthCm !== undefined ? dto.lengthCm : item.lengthCm,
      widthCm: dto.widthCm !== undefined ? dto.widthCm : item.widthCm,
      volumeL: dto.volumeL !== undefined ? dto.volumeL : item.volumeL,
      weightKg: dto.weightKg !== undefined ? dto.weightKg : item.weightKg,
      material: dto.material !== undefined ? dto.material : item.material,
      notes: dto.notes !== undefined ? dto.notes : item.notes,
    });
    return this.gear.save(item);
  }

  async remove(me: string, id: string): Promise<{ ok: boolean }> {
    const item = await this.requireOwned(me, id);
    await this.gear.remove(item);
    return { ok: true };
  }

  private async requireOwned(me: string, id: string): Promise<GearItem> {
    const item = await this.gear.findOne({ where: { id } });
    if (!item) {
      throw new NotFoundException('Gear item not found');
    }
    if (item.userId !== me) {
      throw new ForbiddenException('Only the owner can manage this gear item');
    }
    return item;
  }
}