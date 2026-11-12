import 'reflect-metadata';
import { config as dotenvConfig } from 'dotenv';
import { DataSource } from 'typeorm';

dotenvConfig();

const isProduction = process.env.NODE_ENV === 'production';

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  username: process.env.DB_USERNAME ?? 'postgres',
  password: process.env.DB_PASSWORD ?? 'postgres',
  database: process.env.DB_DATABASE ?? 'sup_fun',
  entities: isProduction
    ? ['dist/**/*.entity.js']
    : ['src/**/*.entity.ts'],
  migrations: isProduction
    ? ['dist/migrations/**/*.js']
    : ['src/migrations/**/*.ts'],
  synchronize: false,
  logging: false,
});