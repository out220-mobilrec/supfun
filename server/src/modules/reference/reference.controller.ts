import { Controller, Get } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { Country } from './country.entity';
import { ReferenceService } from './reference.service';

/**
 * Справочники приложения. Публично: списки нужны и для регистрации,
 * и для мобильного клиента до авторизации.
 */
@Public()
@Controller('reference')
export class ReferenceController {
  constructor(private readonly service: ReferenceService) {}

  /** Страны: ISO 3166-1 alpha-2 + название на русском. */
  @Get('countries')
  countries(): Promise<Country[]> {
    return this.service.listCountries();
  }
}
