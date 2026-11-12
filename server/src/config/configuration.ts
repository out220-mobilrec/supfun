import { TypeOrmModuleOptions } from '@nestjs/typeorm';

export interface AppConfig {
  port: number;
  nodeEnv: string;
  frontendUrl: string;
  jwt: { secret: string; expiresIn: string };
  mail: {
    host: string | undefined;
    port: number;
    secure: boolean;
    user: string | undefined;
    pass: string | undefined;
    from: string;
  };
  marketplace: { autoApprove: boolean };
  database: TypeOrmModuleOptions;
}

export default (): AppConfig => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  frontendUrl: process.env.FRONTEND_URL ?? 'http://localhost:5173',
  jwt: {
    secret: process.env.JWT_SECRET ?? 'sup-fun-dev-secret',
    expiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  },
  mail: {
    host: process.env.MAIL_HOST || undefined,
    port: parseInt(process.env.MAIL_PORT ?? '587', 10),
    secure: process.env.MAIL_SECURE === 'true',
    user: process.env.MAIL_USER || undefined,
    pass: process.env.MAIL_PASS || undefined,
    from: process.env.MAIL_FROM ?? 'no-reply@supfun.app',
  },
  marketplace: {
    autoApprove: process.env.LISTING_AUTO_APPROVE !== 'false',
  },
  database: {
    type: 'postgres',
    host: process.env.DB_HOST ?? 'localhost',
    port: parseInt(process.env.DB_PORT ?? '5432', 10),
    username: process.env.DB_USERNAME ?? 'postgres',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_DATABASE ?? 'sup_fun',
    synchronize: process.env.DB_SYNC === 'true',
    logging: process.env.DB_LOGGING === 'true',
  },
});
